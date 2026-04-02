from pyswip import Prolog

def main():
    prolog = Prolog()
    prolog.consult('./robocup.pl')
    prolog.query('init')

if __name__ == '__main__':
    main()
