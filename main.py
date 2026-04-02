from pyswip import Prolog
import pygame

WIDTH, HEIGHT = 640, 480
FPS = 60

def main():
    # Setup prolog robocup backend
    prolog = Prolog()
    prolog.consult('./robocup.pl')
    prolog.query('init')

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

        # draw start

        screen.fill((0, 255, 0))

        # draw end

        clock.tick(FPS)
        pygame.display.flip()
    pygame.quit()


if __name__ == '__main__':
    main()
