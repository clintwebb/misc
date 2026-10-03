#!/bin/bash

# a math example that can be done in bash.
# https://www.youtube.com/watch?v=LjoyPlWmxJY

# The Rule
#  "A farmer goes to a market and buys goats, rabbits, and ducks.  Altogether, he pays $100 for 100 animals."
#  "1 goat costs $10, 1 rabbit costs $3, and 2 ducks cost $1.  How many goats, rabbits and ducks does he buy?"

# This puzzle can certainly be easy to be done with mathmatics, but here is an example of how to do some math and evaluation on mulitple options.


GOAT_COST=10
RABBIT_COST=3
DUCK_COST=1

MAX_COST=100
MAX_GOATS=$((MAX_COST / GOAT_COST))
MAX_RABBITS=$((MAX_COST / RABBIT_COST))
MAX_DUCKS=$((MAX_COST / DUCK_COST))

for (( GOATS=1; GOATS<=MAX_GOATS; GOATS++ )); do
  for (( RABBITS=1; RABBITS<=MAX_RABBITS; RABBITS++ )); do
    for (( DUCKB=1; DUCKB<=MAX_DUCKS; DUCKB++ )); do

      DUCKS=$((DUCKB * 2))
      COST=$(( GOATS * GOAT_COST + RABBITS * RABBIT_COST + DUCKB * DUCK_COST ))
      ANIMALS=$((GOATS + RABBITS + DUCKS ))

      if [[ $COST -eq 100 && $ANIMALS -eq 100 ]]; then

        echo "Goats:   $GOATS"
        echo "Rabbits: $RABBITS"
        echo "Ducks:   $DUCKS"
        echo
        echo "Total Cost:    $COST"
        echo "Total Animals: $ANIMALS"
        echo
        echo
      fi
    done
  done
done


