# memcpyD
An experiment to explore implementing memcpy in D

## Disclaimer
* I'm not a very good D programmer
* I've not very experienced with Intel architectures
* I'm not very knowledgeable about memory hierarchies
* I don't have much experience benchmarking code
* Currently only implements memory-aligned types with sizes in powers of 2

I'm just trying to reason through this as best as I can

## Why?
Some things go without saying.

## Results so far

Compiled with `dmd -m64 memcpyd.d`.
![](https://raw.githubusercontent.com/JinShil/memcpyD/master/images/win10.png)

Compiled with `dmd memcpyd.d`.
![](https://raw.githubusercontent.com/JinShil/memcpyD/master/images/linux.png)

Graphs generated with gnuplot:
```
set autoscale
set logscale xy 2
plot 'data.txt' using "size":"memcpyC" with lines, '' using "size":"memcpyD" with lines
```