# Leprechaun

Leprechaun is a game based on [Gems of War](https://gemsofwar.com/), the [Threasure Hunt](https://gemsofwar.zendesk.com/hc/en-us/articles/205368765-Treasure-Hunt-and-Treasure-Maps).

The base of the game is swap pieces, only one each time and only with the ones in north, south, east or west of the source one. The combinations should be made by 3 or more in vertical or horizontal way. If you achieve to match 4 then you won't loose a turn and if you achieve match more than 4 then you'll obtain an extra turn. The game starts with 10 turns and ends when you run out of turns.

## Installation

It's easy to install. You only needs to have [Elixir](https://elixir-lang.org/install.html) installed and run this to obtain the code:

```
git clone git@github.com:altenwald/leprechaun.git
```

Then you can see there are a new directory in that path called `leprechaun`. You can go inside using the terminal and write:

```
iex -S mix run
```

The Elixir shell will be running after the compilation. You can start the game using this command:

```elixir
Leprechaun.Game.run
```

Follow the instructions and enjoy!
