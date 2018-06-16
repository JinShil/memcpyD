import std.datetime.stopwatch;
import core.stdc.string;
import std.random;
import std.traits;
import std.stdio;

private struct S16 { ubyte[16] x; }
private struct S32 { ubyte[32] x; }

void memcpyC(T)(T* src, T* dst)
{
    memcpy(dst, src, T.sizeof);
}

void memcpyD(T)(T* src, T* dst)
    if (isScalarType!T)
{
    // writeln("Copying for " ~ T.stringof);
    *dst = *src;
}

void memcpyD(T)(T* src, T* dst)
    if (is(T == struct))
{
    // writeln("Copying for " ~ T.stringof);
    static if (!is(T == ubyte) && T.sizeof == 1)
    {
        memcpyD(cast(ubyte*)src, cast(ubyte*)dst);
        return;
    }
    else static if (!is(T == ushort) && T.sizeof == 2)
    {
        memcpyD(cast(ushort*)src, cast(ushort*)dst);
        return;
    }
    else static if (!is(T == uint) && T.sizeof == 4)
    {
        memcpyD(cast(uint*)src, cast(uint*)dst);
        return;
    }
    else static if (!is(T == ulong) && T.sizeof == 8)
    {
        memcpyD(cast(ulong*)src, cast(ulong*)dst);
        return;
    }
    else static if (T.sizeof == 16)
    {
        version(D_SIMD)
        {
            import core.simd: void16;
            *(cast(void16*)dst) = *(cast(void16*)src);
        }
        else
        {
            static foreach(i; 0 .. T.sizeof/8)
            {
                memcpyD((cast(ulong*)src) + i, (cast(ulong*)dst) + i);
            }
        }

        return;
    }
    else static if (T.sizeof == 32)
    {
        // AVX implementation is unstable in DMD. It sporadically fails.
        version(D_AVX)
        {
            import core.simd: void32;
            *(cast(void32*)dst) = *(cast(void32*)src);
        }
        else
        {
            static foreach(i; 0 .. T.sizeof/16)
            {
                memcpyD((cast(S16*)src) + i, (cast(S16*)dst) + i);
            }
        }

        return;
    }
    else
    {
        version(D_AVX)
        {
            static foreach(i; 0 .. T.sizeof/32)
            {
                memcpyD((cast(S32*)src) + i, (cast(S32*)dst) + i);
            }

            return;
        }
        else version(D_SIMD)
        {
            static if (T.sizeof < 1024)
            {
                static foreach(i; 0 .. T.sizeof/16)
                {
                    memcpyD((cast(S16*)src) + i, (cast(S16*)dst) + i);
                }

                return;
            }

            // else will fall down to `rep movsb` implementation below
        }

        asm pure nothrow @nogc
        {
            mov RSI, src;
            mov RDI, dst;
            cld;
            mov RCX, T.sizeof;
            rep;
            movsb;
        }

        return;
    }
}

// The following 2 functions are an attempt to prevent the compiler
// from removing code when compiling with optimizations.  See
// https://stackoverflow.com/questions/40122141/preventing-compiler-optimizations-while-benchmarking
void use(void* p)
{
    version(LDC)
    {
        import ldc.llvmasm;
         __asm("", "r,~{memory}", p);
    }
}

void clobber()
{
    version(LDC)
    {
        import ldc.llvmasm;
        __asm("", "~{memory}");
    }
}

Duration benchmark(T, alias f)(T* src, T* dst, ulong* bytesCopied)
{
    enum iterations = 2^^20 / T.sizeof;
    Duration result;

    auto swt = StopWatch(AutoStart.yes);
    swt.reset();
    while(swt.peek().total!"nsecs" < 1_000_000_000)
    {
        auto sw = StopWatch(AutoStart.yes);
        sw.reset();
        foreach (_; 0 .. iterations)
        {
            f(src, dst);
            clobber();    // So optimizer doesn't remove code
        }
        result += sw.peek();
        *bytesCopied += (iterations * T.sizeof);
    }

    return result;
}

void init(T)(ref T v)
{
    static if (is (T == float))
    {
        v = uniform(0.0f, 9_999_999.0f);
    }
    else static if (is(T == double))
    {
        v = uniform(0.0, 9_999_999.0);
    }
    else static if (is(T == real))
    {
        v = uniform(0.0L, 9_999_999.0L);
    }
    else
    {
        auto m = (cast(ubyte*) &v)[0 .. T.sizeof];
        for(int i = 0; i < m.length; i++)
        {
            m[i] = uniform!byte;
        }
    }
}

void verify(T)(const ref T a, const ref T b)
{
    auto aa = (cast(ubyte*)&a)[0..T.sizeof];
    auto bb = (cast(ubyte*)&b)[0..T.sizeof];
    for(int i = 0; i < T.sizeof; i++)
    {
        assert(aa[i] == bb[i]);
    }
}

void test(T)()
{
    T d;
    T s;

    init(d);
    init(s);
    memcpyC(&s, &d);
    verify(s, d);

    init(d);
    init(s);
    memcpyD(&s, &d);
    verify(s, d);

    ulong bytesCopied1;
    ulong bytesCopied2;
    immutable d1 = benchmark!(T, memcpyC)(&s, &d, &bytesCopied1);
    immutable d2 = benchmark!(T, memcpyD)(&s, &d, &bytesCopied2);

    auto secs1 = (cast(double)(d1.total!"nsecs")) / 1_000_000_000.0;
    auto secs2 = (cast(double)(d2.total!"nsecs")) / 1_000_000_000.0;
    auto GB1 = (cast(double)bytesCopied1) / 1_000_000_000.0;
    auto GB2 = (cast(double)bytesCopied2) / 1_000_000_000.0;
    auto GBperSec1 = GB1 / secs1;
    auto GBperSec2 = GB2 / secs2;
    writeln(T.sizeof, " ", GBperSec1, " ", GBperSec2);
    stdout.flush();
}

struct S1 { ubyte x; }
struct S2 { ushort x; }
struct S4 { uint x; }
struct S8 { ulong x; }
// struct S16 { ubyte[16] x; }
// struct S32 { ubyte[32] x; }
struct S64 { ubyte[64] x; }
struct S128 { ubyte[128] x; }
struct S256 { ubyte[256] x; }
struct S512 { ubyte[512] x; }
struct S1024 { ubyte[1024] x; }
struct S2048 { ubyte[2048] x; }
struct S4096 { ubyte[4096] x; }
struct S8192 { ubyte[8192] x; }
struct S16384 { ubyte[16384] x; }
struct S32768 { ubyte[32768] x; }
struct S65536 { ubyte[65536] x; }

void main()
{
    // For performing benchmarks
    writeln("size(bytes) memcpyC(GB/s) memcpyD(GB/s)");
    stdout.flush();
    test!S1;
    test!S2;
    test!S4;
    test!S8;
    test!S16;
    test!S32;
    test!S64;
    test!S128;
    test!S256;
    test!S512;
    test!S1024;
    test!S2048;
    test!S4096;
    test!S8192;
    test!S16384;
    test!S32768;
    test!S65536;

    // For testing integrity
    // writeln("");
    // writeln("size(bytes) memcpyC(GB/s) memcpyD(GB/s)");
    // test!bool;
    // test!ubyte;
    // test!byte;
    // test!ushort;
    // test!short;
    // test!uint;
    // test!int;
    // test!ulong;
    // test!long;
    // test!float;
    // test!double;
    // test!real;
}
