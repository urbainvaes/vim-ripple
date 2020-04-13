import time

# `yrap` to run a paragraph
a = 1
b = 2
c = 3

# `yrr` to run line
print("Hello, world!")

# `yp` to rerun previous selection

# `yr}` works here
def hello(name):
    print("Hello, {}!".format(name))

# `yrf"` to run until "
hello("")

# Does not hang on long commands
for i in range(10):
    time.sleep(1)
    print(i)

# Works also with visual selection
print("Hello, world!")
