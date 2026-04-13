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


