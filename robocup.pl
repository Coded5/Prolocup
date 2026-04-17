use_module(library(random)).
% setting them to dynamic so we can change them via retract and assert

:- dynamic player_state/5.
:- dynamic player_stats/4.
:- dynamic ball_state/2.
:- dynamic score/2.
:- dynamic possession/2.
:- dynamic is_over/1.

field(105, 68).       % Standard football field dimensions in meter
goal_range(24, 44).       % Range of y axis for goal

goal_target(team1, 105, 34).       % center of goal for team1 to kick into
goal_target(team2, 0, 34).         % center of goal for team2 to kick into
goalkeeper_radius(20).              % radius from goal center where goalkeeper stay in

win_target(3).     

% random stat generator by role
random_profile(goalkeeper, Speed, Power) :-
    random_between(1, 3, Speed),
    random_between(30, 35, Power).

random_profile(defender, Speed, Power) :-
    random_between(2, 4, Speed),
    random_between(15, 20, Power).

random_profile(forward, Speed, Power) :-
    random_between(3, 5, Speed),
    random_between(25, 30, Power).

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
   retractall(is_over(_)),
   load_player_positions,
   load_player_stats,
   initial_ball(BX, BY),
   assertz(ball_state(BX, BY)),
   assertz(score(0, 0)),
   assertz(possession(none, none)),
   assertz(is_over(0)),
   format('Game initialized.~n').

reset_after_goal :-
    retractall(player_state(_, _, _, _, _)),
    retractall(ball_state(_, _)),
    retractall(possession(_, _)),
    load_player_positions,
    initial_ball(BX, BY),
    assertz(ball_state(BX, BY)),
    assertz(possession(none, none)),
    format('Positions reset after goal.~n').

% Utility predicates (Remove later if these are not used)
sign(X, 1) :- X > 0.
sign(X, -1) :- X < 0.
sign(0, 0).

clamp(Value, Min, _Max, Min) :- Value < Min, !.
clamp(Value, _Min, Max, Max) :- Value > Max, !.
clamp(Value, _, _, Value).

on_same_side(team1, X) :- % check if (ball) X position on same side as player's team
    field(FieldX,_),
    MidFieldX is FieldX // 2,
    X =< MidFieldX.  
on_same_side(team2, X) :- 
    field(FieldX,_),
    MidFieldX is FieldX // 2,
    X >= MidFieldX.

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
    field(Width, Height),
    clamp(NewX, 0, Width, XX),
    clamp(NewY, 0, Height, YY),
    retract(player_state(Team, Id, Role, _, _)),
    assertz(player_state(Team, Id, Role, XX, YY)).

update_ball(NewX, NewY) :-
    field(Width, Height),
    clamp(NewX, 0, Width, XX),
    clamp(NewY, 0, Height, YY),
    retract(ball_state(_, _)),
    assertz(ball_state(XX, YY)).

clear_possession :-
    retractall(possession(_, _)),
    assertz(possession(none, none)).

update_score(team1) :-      % +1 score to the team that goaled
    score(Score1, Score2),
    NewScore1 is Score1 + 1,
    retract(score(_,_)),
    assertz(score(NewScore1, Score2)),
    format('Current Score: ~w - ~w ~n', [NewScore1, Score2]).
update_score(team2) :-
    score(Score1, Score2),
    NewScore2 is Score2 + 1,
    retract(score(_,_)),
    assertz(score(Score1, NewScore2)),
    format('Current Score: ~w - ~w ~n', [Score1, NewScore2]).

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
    MinP is (Power * 4) // 5,
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
pass_ball(Team, Id, Role) :- 
    findall((Team, I, Role), (player_state(Team, I, Role, _, _), Id \= I), Players),
    random_member((_, PassId, _), Players),

    player_state(Team, Id, _, X1, Y1),
    player_stats(Team, Id, _, Power),

    player_state(Team, PassId, Role, X2, Y2),

    distance(X1, Y1, X2, Y2, Distance),
    random_between(-5, 5, RandomY),
    (
        Distance =< Power -> 
            update_ball(X2, Y2)
        ;   
            Y2_inc is Y2 + RandomY,
            advance_ball(X1, Y1, X2, Y2_inc, Power, BX, BY),
            update_ball(BX, BY)
    ),
    retractall(possession(_, _)),
    assertz(possession(Team, PassId)),
    format('~w player ~w passes to ~w.~n', [Team, Id, PassId]).

clear_ball(Team, Id) :-
    possession(Team, Id),
    player_state(Team, Id, _, X, Y),
    player_stats(Team, Id, _, Power),
    MinP is (Power * 4) // 5,
    random_between(MinP, Power, RandomPower),
    goal_target(Team, GX, _),
    field(_,Field_Y),
    random_between(0, Field_Y, Target_Y),
    advance_ball(X, Y, GX, Target_Y, RandomPower, BX, BY),
    update_ball(BX, BY),
    clear_possession,
    format('~w player ~w clears to (~w, ~w).~n', [Team, Id, BX, BY]).

    
% ==============================

move_player(Team, Id, TX, TY) :-
    player_state(Team, Id, Role, X, Y),
    player_stats(Team, Id, Speed, _),
    distance(X, Y, TX, TY, Distance),
    random_between(-2, 2, RandomY),

    ( Distance =< Speed -> 

        update_player(Team, Id, Role, TX, TY) ;

        % move toward point (TX, TY) for (Speed) units
        XX is X + (TX - X) / Distance * Speed,
        YY is Y + (TY - Y + RandomY) / Distance * Speed,

        update_player(Team, Id, Role, XX, YY)
    ).

% Forward

forward_action(Team, Id):-
    ( possession(Team, Id) ->
        distance_to_goal(Team, Id, Distance),
        player_stats(Team, Id, _, Power),
        ( Distance =< Power -> 
            shoot_ball(Team, Id)
        ;
            random_between(0, 7, X),
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

% Goalkeeper

goalkeeper_action(Team, Id):-
    (
        possession(Team, Id) ->                 % possess ball then kick away from goal
        shoot_ball(Team, Id)         
        ;
        goal_target(Op_Team, GX, GY),              % dont possess ball then move towards ball
        Team \= Op_Team,
        ball_state(BX, BY),
        distance(GX, GY, BX, BY, G_B_Dist),
        goalkeeper_radius(R),

        (   R >= G_B_Dist ->                     
                move_player(Team, Id, BX, BY)   % ball inside active zone then run to ball
            ;
                DX is BX - GX,                  % run towards ball but stay inside zone
                DY is BY - GY,
                EX is GX + (DX / G_B_Dist) * R,   % edge of allowed radus 
                EY is GY + (DY / G_B_Dist) * R,
                move_player(Team, Id, EX, EY)  
        )
    ).

% defender

defender_action(Team, Id) :-
    (
        possession(Team, Id) ->                             % if possess the ball then pass to forward or clear
        random_between(0, 1, X),
            ( X = 0 ->
                pass_ball(Team, Id, forward) 
            ;   
                clear_ball(Team, Id)
            )
        ; (ball_state(BX, BY), on_same_side(Team, BX)) ->   % if not possess ball but ball on same side, try to run to it
            move_player(Team , Id, BX, BY)
        ; home_position(Team, Id, defender, HX, HY),         % if ball on other side run to wait at half line
            move_player(Team, Id, HX, HY)
    )
    .    

% scoring logic
check_goal :- 
    ball_state(BX, BY),
    goal_range(MinY, MaxY),
    ((BX == 105, BY >= MinY, BY =< MaxY) ->
        format('GOAL for team1!~n'),
        update_score(team1),
        reset_after_goal
    ; (BX == 0, BY >= MinY, BY =< MaxY) ->
        format('GOAL for team2!~n'),
        update_score(team2),
        reset_after_goal
    ; true
    ).   

% main_loop
main_loop:-     % start game with max number of turns, stop when a team wins or when run out of turns
    step,
    main_loop.

step :-
    % randomize player
    score(Score1, Score2),
    win_target(Score),
    ( (Score1 == Score) ->
        format('Team 1 wins! ~n'), 
        retractall(is_over(_)),
        assertz(is_over(1)),
        !;
      (Score2 == Score) ->
        format('Team 2 wins! ~n'), 
        retractall(is_over(_)),
        assertz(is_over(2)),
        !;
    
        findall((Team, Id, Role), player_state(Team, Id, Role, _, _), Players),
        random_permutation(Players, Shuffled),
        ministep(Shuffled)
    )
    .

ministep([_, _, _, _, _]):- !.
ministep([FirstPlayer | PlayerList]) :-
    check_goal,
    FirstPlayer = (Chosen_Team, Chosen_Id, Chosen_Role),
    %   check possession
    update_possession(Chosen_Team, Chosen_Id),
    (
    Chosen_Role = goalkeeper -> goalkeeper_action(Chosen_Team, Chosen_Id), update_possession(Chosen_Team, Chosen_Id), goalkeeper_action(Chosen_Team, Chosen_Id);
    Chosen_Role = forward -> forward_action(Chosen_Team, Chosen_Id)  ;
    Chosen_Role = defender -> defender_action(Chosen_Team, Chosen_Id), update_possession(Chosen_Team, Chosen_Id),defender_action(Chosen_Team, Chosen_Id)
    ),
    ministep(PlayerList).


update_possession(Team, Id):-       % when turn start, check if player can possess ball
    ball_state(BX, BY),
    player_state(Team, Id, _, PX, PY),
    distance(PX, PY, BX, BY, D),
    D < 0.5,
    retractall(possession(_,_)),
    assertz(possession(Team, Id)),
    format('~w player ~w possessed the ball.~n', [Team, Id]),
    !.
update_possession(_,_).
