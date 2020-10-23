import random
from abc import ABC, abstractmethod
from itertools import product


class Painter(ABC):
    @abstractmethod
    def paint(self, buffer, time: int):
        pass


class LinePainter(Painter):
    def __init__(self, width: int, height: int, margin: int):
        self.width = width
        self.height = height
        self.margin = margin
        self.line_pos = height // 2
        self.line_speed = random.choice([-2, -1, 1, 2])
        self.colors = [bytes(x) + b"\xff" for x in product([i * 16 + i for i in range(16)], repeat=3)]
        self.color = None
        self.pick_color()

    def paint(self, buffer, time: int):
        if not time:
            # Clear
            buffer.seek(0)
            buffer.write(b"\xff" * 4 * self.width * self.height)

        # Draw progressing line
        buffer.seek((self.line_pos * self.width + self.margin) * 4)
        buffer.write(self.color * (self.width - 2 * self.margin))
        self.line_pos += self.line_speed

        # Reverse and change color
        if self.line_pos >= self.height - self.margin or self.line_pos <= self.margin:
            self.line_speed = -self.line_speed
            self.pick_color()

    def pick_color(self):
        while (color := random.choice(self.colors)) == self.color:
            pass
        self.color = color
