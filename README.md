# Requirements

[Zig]{https://ziglang.org/download/}

# Running the project 

First, clone the repository or download and extract the archive. Open a terminal in the newly cloned/extracted directory. 

To benchmark the different implementations normally, run `zig build run` in the project directory. To run with the deoptimizer, run `zig build run -Doptimize=ReleaseFast`. 

# About

The goal of this project is to benchmark two different implementations of a perfect hash across an arbitrary dictionary (using standard a-z characters) against a typical hashmap. The program will build and access all entries in the map, test the speed, then verify they worked correctly. 