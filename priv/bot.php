<?php

$move = [];
$points = 0;

$options = [ [0, -1],
       [-1, 0],
       [0, 1],
       [1, 0] ];

function get_points($matches) {
  global $board;
  $points = 0;
  foreach ($matches as $match) {
    foreach ($match[1] as $coords) {
      $points += leprechaun_get_points($coords[0], $coords[1]);
    }
    if (count($match[1]) > 3) {
      $points *= 100;
    }
    if (count($match[1]) > 4) {
      $points *= 1000;
    }
  }
  return $points;
}

for ($i=1; $i<=8; $i++) {
  for ($j=1; $j<=8; $j++) {
    foreach ($options as $k) {
      $x = $i + $k[0];
      $y = $j + $k[1];
      if ($x >= 1 and $x <= 8 and $y >= 1 and $y <= 8) {
        $result = leprechaun_check_move($i, $j, $x, $y);
        $found_points = get_points($result["matches"]);
        if ($result["check"] and $found_points > $points) {
          $move = [$i, $j, $x, $y];
          $points = $found_points;
        }
      }
    }
  }
}
if ($points > 0) {
  leprechaun_move($move[0], $move[1], $move[2], $move[3]);
}
