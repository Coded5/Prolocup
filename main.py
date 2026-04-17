from pyswip import Prolog
import pygame

WIDTH, HEIGHT = 1280, 720
FPS = 90

FIELD_WIDTH = 105
FIELD_HEIGHT = 68
SCALE = 8

CENTER_OFFSET_X = (WIDTH - (FIELD_WIDTH * SCALE)) // 2
CENTER_OFFSET_Y = (HEIGHT - (FIELD_HEIGHT * SCALE)) // 2

FIELD_COLOR = (34, 117, 44)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
YELLOW = (255, 255, 0)
BLUE = (0, 0, 255)

LERP_TIME = 0.2

# Reverse / Forward

class PrologGameState:
    def __init__(self):
        self.prolog = Prolog()
        self.prolog.consult('./robocup.pl')
        list(self.prolog.query('init_game'))

        self.game_states = []
        self.game_over = False
        self.winner = ""
        self.fetch_game_state()
        self.fetch_game_state()

    def fetch_game_state(self):
        ball_position = self.query('ball_state(X, Y)')

        if ball_position is None:
            return

        score_data = self.query('score(Team1, Team2)')
        possession = self.query('possession(Team, Id)')
        over = self.query('is_over(Over)')

        if over is not None:
            if over['Over'] == 1:
                self.winner = "Team 1 wins!"
                self.game_over = True
            elif over['Over'] == 2:
                self.winner = "Team 2 wins!"
                self.game_over = True

        state = {
                "ball_x": ball_position['X'],
                "ball_y": ball_position['Y'],
                "score": score_data,
                "possession": possession
        }


        players = {}
        for player in list(self.prolog.query('player_state(Team, Id, Role, X, Y)')):
            team = player['Team'] # Team1, Team2
            id = player['Id']
            role = player['Role']
            x = player['X']
            y = player['Y']

            players[f"{team}_{id}"] = {
                "team" : team, # Team1, Team2,
                "id" : id,
                "role" : role,
                "x" : x,
                "y" : y
            }

        state['players'] = players

        self.game_states.append(state)

    def step(self):
        if self.game_over:
            self.game_over = False
            self.winner = ""
            list(self.prolog.query('init_game'))

        list(self.prolog.query('step'))

    def query(self, query):
        result = list(self.prolog.query(query))

        if len(result) == 0:
            return None

        return result[0]

def field_to_screen(position):
    return (CENTER_OFFSET_X + position[0] * SCALE, CENTER_OFFSET_Y + position[1] * SCALE)

def lerp(a, b, t):
    return a + t * (b - a)

def main():
    game = PrologGameState()

    pygame.init()
    font = pygame.font.SysFont("Arial", 32)
    player_font = pygame.font.SysFont("Arial", 18)
    pygame.display.set_caption('Prolocup')

    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    clock = pygame.time.Clock()

    lerp_t = 1

    running = True
    autoplay = False
    current = -1

    prev = game.game_states[current-1]
    curr = game.game_states[current]

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                # if event.key == pygame.K_k:
                #     game.step()
                #     game.fetch_game_state()
                #     lerp_t = 0
                if event.key == pygame.K_SPACE:
                    autoplay = not autoplay


                if event.key == pygame.K_LEFT:
                    autoplay = False
                    current -= 1
                    lerp_t = 0
                    prev = curr
                    curr = game.game_states[current]
                if event.key == pygame.K_RIGHT:
                    autoplay = False

                    if current != -1:
                        current += 1
                    else:
                        game.step()
                        game.fetch_game_state()

                    prev = curr
                    curr = game.game_states[current]

                    lerp_t = 0


        screen.fill(FIELD_COLOR)

        pygame.draw.rect(
                screen,
                WHITE,
                (CENTER_OFFSET_X, CENTER_OFFSET_Y, 105 * SCALE, 68 * SCALE)
                , 3, 1
        )

        team1_score = game.game_states[current]['score']['Team1']
        team2_score = game.game_states[current]['score']['Team2']

        score_text = f"{team1_score} - {team2_score}"
        text_surf = font.render(score_text, True, WHITE)

        xx = (WIDTH - text_surf.get_width()) // 2
        screen.blit(text_surf, (xx, 50))

        pygame.draw.line(screen, WHITE, field_to_screen((FIELD_WIDTH // 2, 0)), field_to_screen((FIELD_WIDTH // 2, FIELD_HEIGHT)), 3)

        pygame.draw.circle(screen, WHITE, field_to_screen((FIELD_WIDTH // 2, FIELD_HEIGHT // 2)), 60, 2)

        # Left Rect
        pygame.draw.rect(
                screen,
                WHITE,
                (CENTER_OFFSET_X, CENTER_OFFSET_Y + (68 * SCALE //4), 105 * SCALE // 5, 68 * SCALE // 2),
                3, 1
                )
        
        # Right rect
        pygame.draw.rect(
                screen,
                WHITE,
                (CENTER_OFFSET_X + 105 * SCALE // 5 * 4,CENTER_OFFSET_Y + (68 * SCALE //4), 105 * SCALE // 5, 68 * SCALE // 2),
                3, 1
                )

        # Left goal
        pygame.draw.rect(
                screen,
                WHITE,
                (
                    CENTER_OFFSET_X - (5 * SCALE),
                    CENTER_OFFSET_Y + (68 - 20) * SCALE // 2,
                    5 * SCALE,
                    20 * SCALE
                )
        )

        # Right goal
        pygame.draw.rect(
                screen,
                WHITE,
                (
                    CENTER_OFFSET_X + 105 * SCALE,
                    CENTER_OFFSET_Y + (68 - 20) * SCALE // 2,
                    5 * SCALE,
                    20 * SCALE
                )
        )

        # Jank
        if abs(current) >= len(game.game_states):
            current = -1

        # prev = game.game_states[current-1]
        # curr = game.game_states[current]


        ball = (
            lerp(prev['ball_x'], curr['ball_x'], lerp_t),
            lerp(prev['ball_y'], curr['ball_y'], lerp_t)
        )

        lerp_t += (1 / (FPS * LERP_TIME))
        lerp_t = min(1, lerp_t)

        possesion = game.game_states[current]['possession']

        for player in game.game_states[current]['players'].keys():
            curr_player = curr['players'][player]
            prev_player = prev['players'][player]

            
            player_num_surface = player_font.render(str(curr_player['id']), True, WHITE)

            color = RED if curr_player['team'] == 'team1' else BLUE

            x = lerp(prev_player['x'], curr_player['x'], lerp_t)
            y = lerp(prev_player['y'], curr_player['y'], lerp_t)

            xx, yy = field_to_screen((x, y))

            highlight = possesion['Team'] == curr_player['team'] and possesion['Id'] == curr_player['id']


            if highlight:
                pygame.draw.circle(screen, YELLOW, field_to_screen((x, y)), 15)

            pygame.draw.circle(screen, color, field_to_screen((x, y)), 12)

            # 2. Draw the outline (hollow)
            pygame.draw.circle(screen, (0, 0, 0), field_to_screen((x, y)), 12, width=3)
            screen.blit(player_num_surface, (xx - 6, yy - 12))


        pygame.draw.circle(screen, WHITE, field_to_screen(ball), 5) 
        # draw end

        if lerp_t >= 1 and autoplay:
            game.step()
            game.fetch_game_state()

            prev = curr
            curr = game.game_states[current]
            lerp_t = 0

        if game.game_over:
            win_bg = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            win_bg.fill((0, 0, 0, 128))
            screen.blit(win_bg, (0, 0))
            win_surf = font.render(f"{game.winner}", True, YELLOW)
            screen.blit(win_surf, win_surf.get_rect(center=(WIDTH//2, HEIGHT//2)))

            autoplay = False

        
        clock.tick(FPS)
        pygame.display.flip()

    pygame.quit()


if __name__ == '__main__':
    main()
