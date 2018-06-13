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
D currently has a hard dependency on the C standard library.  I believe the reasons for this have more to do with expediency than deliberate intent.  D would be more portable and easier to cross-compile to new platforms if users didn't have to obtain a C toolchain to use D.

Also, due to the fact that at one time D did not have templates or compile-time execution, many implementations in the D runtime are using runtime time information.  Modern D has templates and compile-time execution, so by rewriting the D runtime implementations using those metaprogramming facilities, we can potentially achieve better performance.  Also, the runtime could be used in [-betterC](https://dlang.org/spec/betterc.html) code, which currently doesn't support runtime type information.  To do that, however, we need templated building blocks like memcpy and memcmp to take advantage of the compile-time type information.  This is the part of the reason why memcpyD has a templated, strong-typed interface; `memcpyD(T src, T dst)` over C's `memcpy(void* dst, void* src, size_t length)`.  D can use the compile-time type information (e.g. size and alignment) to generate optimal implementations using D's metaprogramming facilities.

It is unlikely this code will ever be used by D programmers directly.  This is because D already has syntax like `dst[] = src[]`.  That syntax gets lowered to the aforementioned runtime implementations, and those runtime implementations will instantiate a memcpyD template as necessary.

Although grossly incomplete, the current implementation of memcpyD is cohesive and simple.  This makes it much easier to understand, predict, port, and enhance.  Many implementations in C, on the other hand, are quite complex, and due to the special treatment it's given by the compiler, the only way to know what's actually happening is to decompile the executable and analyze the assembly code (Yuck!).

It is not a goal of this endeavor to implement a faster memcpy in D, but rather to implement a suitable substitute in D.  But, if we manage to squeeze some more performance out of the D implementation, that'd be great!

## Results so far

memcpyD, so far, is able to meet or beat memcpyC's performance in most tests.

### Windows 10
Compiled with `dmd -m64 memcpyd.d`.
![](https://raw.githubusercontent.com/JinShil/memcpyD/master/images/win10.png)


### Linux VirtualBox Guest
Compiled with `dmd memcpyd.d`.
![](https://raw.githubusercontent.com/JinShil/memcpyD/master/images/linux.png)

I don't know why memcpyD outperforms memcpyC in VirtualBox, but I believe it is a fluke.  I don't expect such results on real hardware.


### Graph Generation
Graphs generated with gnuplot:
```
set autoscale
set logscale xy 2
plot 'data.txt' using "size":"memcpyC" with lines, '' using "size":"memcpyD" with lines
```