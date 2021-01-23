import random
from abc import ABC, abstractmethod
from itertools import product


class Painter(ABC):
    def __init__(self, width: int, height: int, scale: int):
        self.width = width
        self.height = height
        self.scale = scale

    @abstractmethod
    def paint(self, buffer, time: int):
        pass


class LinePainter(Painter):
    def __init__(self, width: int, height: int, scale: int, margin: int):
        super().__init__(width, height, scale)
        self.margin = margin
        self.line_pos = height // 2
        self.line_speed = random.choice([-1, 1])
        self.colors = [bytes(x) + b"\xff" for x in product([i * 16 + i for i in range(16)], repeat=3)]
        self.color = None
        self.pick_color()

    def paint(self, buffer, time: int):
        width = self.width * self.scale
        height = self.height * self.scale
        margin = self.margin * self.scale
        pos = self.line_pos * self.scale
        size = height * width

        # Clear
        buffer.seek(0)
        buffer.write(b"\xff" * 4 * size)

        # Draw progressing line
        for i in range(self.scale):
            try:
                buffer.seek(((pos + i) * width + margin) * 4)
                size = width - 2 * margin
                buffer.write(self.color * size)
            except ValueError as e:
                print(e)

        self.line_pos += self.line_speed

        # Reverse and change color
        if (
            (self.line_speed > 0 and pos + self.scale - 1 >= height - margin)
            or (self.line_speed < 0 and pos <= margin)
        ):
            self.line_speed = -self.line_speed
            self.pick_color()

    def pick_color(self):
        while (color := random.choice(self.colors)) == self.color:
            pass
        self.color = color
