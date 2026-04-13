% setting them to dynamic so we can change them via retract and assert

:- dynamic player_state/5.
:- dynamic player_stats/4.
:- dynamic ball_state/2.
:- dynamic score/2.
:- dynamic possession/2.
:- dynamic last_touch/1.

field(105, 68).       % Standard football field dimensions in meter
goal_range(30, 38).       % Range of y axis for goal

goal_target(team1, 105, 34).       % center of goal for team1 to kick into
goal_target(team2, 0, 34).         % center of goal for team2 to kick into

% random stat generator by role
random_profile(goalkeeper, Speed, Power) :-
    random_between(1, 3, Speed),
    random_between(30, 40, Power).

random_profile(defender, Speed, Power) :-
    random_between(2, 4, Speed),
    random_between(10, 20, Power).

random_profile(forward, Speed, Power) :-
    random_between(3, 5, Speed),
    random_between(15, 25, Power).

% here we initialize the position of players and ball

home_position(team1, 1, goalkeeper, 5, 34).
home_position(team1, 2, defender, 30, 15).
home_position(team1, 3, defender, 30, 53).
home_position(team1, 4, forward, 40, 25).
home_position(team1, 5, forward, 40, 43).

home_position(team2, 1, goalkeeper, 100, 34).
home_position(team2, 2, defender, 75, 15).
home_position(team2, 3, defender, 75, 53).
home_position(team2, 4, forward, 65, 25).
home_position(team2, 5, forward, 65, 43).

initial_ball(52, 34).       % middle of the field

opponent(team1, team2).
opponent(team2, team1).

% load only player positions
load_player_positions :-
    forall(
        home_position(Team, Id, Role, X, Y),
        assertz(player_state(Team, Id, Role, X, Y))
    ).


% Noted that I seperate these because I want to reset positions without changing stats after a goal.
% load only player stats
load_player_stats :-
    forall(
        home_position(Team, Id, Role, _, _),
        (
            random_profile(Role, Speed, Power),
            assertz(player_stats(Team, Id, Speed, Power))
        )
    ).

% When start game the main the different is this one has the load player stats 
init_game :-
   retractall(player_state(_, _, _, _, _)),
   retractall(player_stats(_, _, _, _)),
   retractall(ball_state(_, _)),
   retractall(score(_, _)),
   retractall(possession(_, _)),
   retractall(last_touch(_)),
   load_player_positions,
   load_player_stats,
   initial_ball(BX, BY),
   assertz(ball_state(BX, BY)),
   assertz(score(0, 0)),
   assertz(possession(none, none)),
   assertz(last_touch(none)),
   format('Game initialized.~n').

reset_after_goal :-
    retractall(player_state(_, _, _, _, _)),
    retractall(ball_state(_, _)),
    retractall(possession(_, _)),
    retractall(last_touch(_)),
    load_player_positions,
    initial_ball(BX, BY),
    assertz(ball_state(BX, BY)),
    assertz(possession(none, none)),
    assertz(last_touch(none)),
    format('Positions reset after goal.~n').

% Utility predicates (Remove later if these are not used)
sign(X, 1) :- X > 0.
sign(X, -1) :- X < 0.
sign(0, 0).

clamp(Value, Min, _Max, Min) :- Value < Min, !.
clamp(Value, _Min, Max, Max) :- Value > Max, !.
clamp(Value, _, _, Value).

distance(X1, Y1, X2, Y2, Distance) :-
    DX is X2 - X1,
    DY is Y2 - Y1,
    SUM is DX * DX + DY * DY,
    sqrt(SUM, Distance).

distance_to_goal(Team, Id, Distance):-
    player_state(Team, Id, _, X, _),
    goal_target(Team, X_target, _),
    Distance is abs(X - X_target), !.

step_towards(X, Y, TX, TY, NX, NY) :-
    DX0 is TX - X,
    DY0 is TY - Y,
    sign(DX0, DX),
    sign(DY0, DY),
    field(MaxX, MaxY),
    X1 is X + DX,
    Y1 is Y + DY,
    clamp(X1, 0, MaxX, NX),
    clamp(Y1, 0, MaxY, NY).

advance_ball(X, Y, _, _, 0, X, Y) :- !.
advance_ball(X, Y, Target_X, Target_Y, Steps, New_X, New_Y):-
    Steps > 0,
    step_towards(X, Y, Target_X, Target_Y, X1, Y1),
    S1 is Steps - 1,
    advance_ball(X1, Y1, Target_X, Target_Y, S1, New_X, New_Y).

update_player(Team, Id, Role, NewX, NewY) :-
    retract(player_state(Team, Id, Role, _, _)),
    assertz(player_state(Team, Id, Role, NewX, NewY)).

update_ball(NewX, NewY) :-
    retract(ball_state(_, _)),
    assertz(ball_state(NewX, NewY)).

clear_possession :-
    retractall(possession(_, _)),
    assertz(possession(none, none)).

% Actions

shoot_ball(Team, Id):-
    possession(Team, Id),
    ball_state(BX, BY),
    goal_target(Team, GX, _),
    goal_range(GY1, GY2),
    MinGY is GY1 -5,
    MaxGY is GY2 + 5,
    random_between(MinGY, MaxGY, RandomGY),
    player_stats(Team, Id, _, Power),
    MinP is Power // 2,
    random_between(MinP, Power, RandomPower),
    advance_ball(BX, BY, GX, RandomGY, RandomPower, NBX, NBY),
    update_ball(NBX, NBY),
    clear_possession,
    format('~w player ~w shoots the ball to (~w, ~w) [PWR ~w].~n', [Team, Id, NBX, NBY, RandomPower]).

dribble_towards_goal(Team, Id) :-
    possession(Team, Id),
    player_state(Team, Id, Role, X, Y),
    player_stats(Team, Id, Speed, _),
    goal_target(Team, GX, GY),
    advance_ball(X, Y, GX, GY, Speed, NX, NY),
    update_player(Team, Id, Role, NX, NY),
    update_ball(NX, NY),
    format('~w player ~w dribbles to (~w, ~w).~n', [Team, Id, NX, NY]).

% ==== Need Implementations ====
pass_ball(Team, Id, forward).
% ==============================

move_player(Team, Id, TX, TY) :-
    player_state(Team, Id, Role, X, Y),
    player_stats(Team, Id, Speed, _),
    distance(X, Y, TX, TY, Distance),

    ( Distance =< Speed -> 
        update_player(Team, Id, Role, TX, TY) ;

        % move toward point (TX, TY) for (Speed) units
        XX is (TX - X) / Distance * Speed,
        YY is (TY - Y) / Distance * Speed,

        update_player(Team, Id, Role, XX, YY)
    ).

% Forward

forward_action(Team, Id):-
    ( possession(Team, Id) ->
        distance_to_goal(Team, Id, Distance),
        ( Distance =< 25 -> 
            shoot_ball(Team, Id)
        ;
            random_between(0, 1, X),
            ( X = 0 ->
                pass_ball(Team, Id, forward) 
            ;   
                dribble_towards_goal(Team, Id)
            )
        )
    ;
        ball_state(BX, BY),
        move_player(Team, Id, BX, BY)
    ).
