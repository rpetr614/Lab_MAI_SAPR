print('Лабораторная работа №1 по САПР')
print('Автор: Петр Р., группа М3О-409-Б22')
print('Результат проверки: 2 + 2 =', 2 + 2)

def factorial(n):
    """Вычисляет факториал числа n"""
    if n == 0 or n == 1:
        return 1
    else:
        return n * factorial(n - 1)

if __name__ == '__main__':
    print('Факториал 5 =', factorial(5))
