from pyswip import Prolog
import pygame

WIDTH, HEIGHT = 1280, 720
FPS = 1

FIELD_WIDTH = 105
FIELD_HEIGHT = 68
SCALE = 8

CENTER_OFFSET_X = (WIDTH - (FIELD_WIDTH * SCALE)) // 2
CENTER_OFFSET_Y = (HEIGHT - (FIELD_HEIGHT * SCALE)) // 2

FIELD_COLOR = (34, 117, 44)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
BLUE = (0, 0, 255)

class PrologGameState:
    def __init__(self):
        self.prolog = Prolog()
        self.prolog.consult('./robocup.pl')
        list(self.prolog.query('init_game'))

        self.fetch_game_state()

    def fetch_game_state(self):
        ball_position = self.query('ball_state(X, Y)')

        if ball_position is None:
            return

        self.ball_position = (ball_position['X'], ball_position['Y'])
        self.player_states = list(self.prolog.query('player_state(Team, Id, Role, X, Y)'))



    def query(self, query):
        result = list(self.prolog.query(query))

        if len(result) == 0:
            return None

        return result[0]

def field_to_screen(position):
    return (CENTER_OFFSET_X + position[0] * SCALE, CENTER_OFFSET_Y + position[1] * SCALE)

def main():
    game = PrologGameState()

    pygame.init()
    pygame.display.set_caption('Prolocup')

    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    clock = pygame.time.Clock()

    running = True

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        list(game.prolog.query('main_loop(1)'))
        game.fetch_game_state()
        # draw start

        screen.fill(FIELD_COLOR)

        pygame.draw.rect(
                screen,
                WHITE,
                (CENTER_OFFSET_X, CENTER_OFFSET_Y, 105 * SCALE, 68 * SCALE)
                , 3, 1
        )

        pygame.draw.line(screen, WHITE, field_to_screen((FIELD_WIDTH // 2, 0)), field_to_screen((FIELD_WIDTH // 2, FIELD_HEIGHT)), 3)

        pygame.draw.circle(screen, WHITE, field_to_screen((FIELD_WIDTH // 2, FIELD_HEIGHT // 2)), 60, 2)

        for player in game.player_states:
            color = RED if player['Team'] == 'team1' else BLUE
            x = player['X']
            y = player['Y']
            # role = player['Role'][:3]

            pygame.draw.circle(screen, color, field_to_screen((x, y)), 8)



        pygame.draw.circle(screen, WHITE, field_to_screen(game.ball_position), 5) 
        # draw end

        clock.tick(FPS)
        pygame.display.flip()

    pygame.quit()


if __name__ == '__main__':
    main()
