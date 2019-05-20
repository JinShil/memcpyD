import std.datetime.stopwatch;
import core.stdc.string;
import std.random;
import std.traits;
import std.stdio;

struct S(size_t Size)
{
    ubyte[Size] x;
}

bool isPowerOf2(T)(T x)
    if (isIntegral!T)
{
    return (x != 0) && ((x & (x - 1)) == 0);
}

void memcpyC(T)(T* dst, const T* src)
{
    pragma(inline, true)
    memcpy(dst, src, T.sizeof);
}

void memcpyD(T)(T* dst, const T* src)
    if (isScalarType!T)
{
    pragma(inline, true)
    *dst = *src;
}

void memcpyDRepMovsb(T)(T* dst, const T* src)
{
    // pragma(inline, true) // cannot inline a function with ASM in DMD
    asm pure nothrow @nogc
    {
        mov RSI, dst;
        mov RDI, src;
        cld;
        mov RCX, T.sizeof;
        rep;
        movsb;
    }
}

// This implementation can't be @safe because it does
// pointer arithmetic
private void memcpyDUnsafe(T)(T* dst, const T* src) @trusted
    if (is(T == struct))
{
    pragma(inline, true)
    static if (T.sizeof == 3)
    {
        memcpyD(cast(ushort*)dst, cast(const ushort*)src);
        memcpyD(cast(ubyte*)dst + ushort.sizeof, cast(const ubyte*)src + ushort.sizeof);
        return;
    }
    else static if (T.sizeof == 5)
    {
        memcpyD(cast(uint*)dst, cast(const uint*)src);
        memcpyD(cast(ubyte*)dst + uint.sizeof, cast(const ubyte*)src + uint.sizeof);
        return;
    }
    else static if (T.sizeof == 6)
    {
        auto s = cast(const uint*)src;
        auto d = cast(uint*)dst;
        memcpyD(d, s);
        memcpyD(cast(ushort*)(d + 1), cast(const ushort*)(s + 1));
        return;
    }
    else static if (T.sizeof == 7)
    {
        auto s = cast(const uint*)src;
        auto d = cast(uint*)dst;
        memcpyD(d, s);
        memcpyD(cast(S!3*)(d + 1), cast(const S!3*)(s + 1));
        return;
    }
    else static if (T.sizeof == 9)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(ubyte*)(d + 1), cast(const ubyte*)(s + 1));
        return;
    }
    else static if (T.sizeof == 10)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(ushort*)(d + 1), cast(const ushort*)(s + 1));
        return;
    }
    else static if (T.sizeof == 11)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(S!3*)(d + 1), cast(const S!3*)(s + 1));
        return;
    }
    else static if (T.sizeof == 12)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(uint*)(d + 1), cast(const uint*)(s + 1));
        return;
    }
    else static if (T.sizeof == 13)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(S!5*)(d + 1), cast(const S!5*)(s + 1));
        return;
    }
    else static if (T.sizeof == 14)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(S!6*)(d + 1), cast(const S!6*)(s + 1));
        return;
    }
    else static if (T.sizeof == 15)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(S!7*)(d + 1), cast(const S!7*)(s + 1));
        return;
    }
    else static if (T.sizeof == 17)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(ubyte*)(d + 1), cast(const ubyte*)(s + 1));
        return;
    }
    else static if (T.sizeof == 18)
    {
        auto s = cast(const ulong*)src;
        auto d = cast(ulong*)dst;
        memcpyD(d, s);
        memcpyD(cast(ushort*)(d + 1), cast(const ushort*)(s + 1));
        return;
    }
}

void memcpyD(T)(T* dst, const T* src)
    if (is(T == struct))
{
    static if (T.sizeof == 1)
    {
        pragma(inline, true)
        memcpyD(cast(ubyte*)dst, cast(const ubyte*)src);
        return;
    }
    else static if (T.sizeof == 2)
    {
        pragma(inline, true)
        memcpyD(cast(ushort*)dst, cast(const ushort*)src);
        return;
    }
    else static if (T.sizeof == 4)
    {
        pragma(inline, true)
        memcpyD(cast(uint*)dst, cast(const uint*)src);
        return;
    }
    else static if (T.sizeof == 8)
    {
        pragma(inline, true)
        memcpyD(cast(ulong*)dst, cast(const ulong*)src);
        return;
    }
    else static if (T.sizeof == 16)
    {
        pragma(inline, true)
        version(D_SIMD)
        {
            pragma(msg, "SIMD");
            import core.simd: void16, storeUnaligned, loadUnaligned;
            storeUnaligned(cast(void16*)dst, loadUnaligned(cast(const void16*)src));
        }
        else
        {
            static foreach(i; 0 .. T.sizeof/8)
            {
                memcpyD((cast(ulong*)dst) + i, (cast(const ulong*)src) + i);
            }
        }

        return;
    }
    else static if (T.sizeof < 32 && !isPowerOf2(T.sizeof))
    {
        pragma(inline, true)
        memcpyDUnsafe(dst, src);
        return;
    }
    else static if (T.sizeof == 32)
    {
        pragma(inline, true)
        // AVX implementation is unstable in DMD. It sporadically fails.
        version(D_AVX)
        {
            import core.simd: void32;
            *(cast(void32*)src) = *(cast(const void32*)dst);
        }
        else
        {
            static foreach(i; 0 .. T.sizeof/16)
            {
                memcpyD((cast(S!16*)dst) + i, (cast(const S!16*)src) + i);
            }
        }

        return;
    }
    else
    {
        version(D_AVX)
        {
            pragma(msg, "AVX");
            static foreach(i; 0 .. T.sizeof/32)
            {
                memcpyD((cast(S!32*)dst) + i, (cast(const S!32*)src) + i);
            }

            return;
        }
        else
        version(D_SIMD)
        {
            static if (T.sizeof <= 1024)
            {
                import core.simd: void16, storeUnaligned, loadUnaligned;

                static foreach(i; 0 .. T.sizeof/16)
                {
                    // This won't inline in DMD for some reason
                    // pragma(inline, true)
                    // memcpyD((cast(const S16*)dst) + i, (cast(S16*)src) + i);

                    storeUnaligned((cast(void16*)dst) + i, loadUnaligned((cast(const void16*)src) + i));
                }

                return;
            }
            else
            {
                pragma(inline, true)
                memcpyDRepMovsb(dst, src);

                return;
            }
        }
        else
        {
            pragma(inline, true)
            memcpyDRepMovsb(dst, src);

            return;
        }
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
    version(GNU)
    {
        asm { "" : : "g" p : "memory"; }
    }
}

void clobber()
{
    version(LDC)
    {
        import ldc.llvmasm;
        __asm("", "~{memory}");
    }
    version(GNU)
    {
        asm { "" : : : "memory"; }
    }
}

Duration benchmark(T, alias f)(T* dst, T* src, ulong* bytesCopied)
{
    enum iterations = 2^^20 / T.sizeof;
    Duration result;

    auto swt = StopWatch(AutoStart.yes);
    swt.reset();
    while(swt.peek().total!"msecs" < 200)
    {
        auto sw = StopWatch(AutoStart.yes);
        sw.reset();
        foreach (_; 0 .. iterations)
        {
            use(dst);   // So optimizer doesn't remove code
            f(dst, src);
            use(src);   // So optimizer doesn't remove code
        }
        result += sw.peek();
        *bytesCopied += (iterations * T.sizeof);
    }

    return result;
}

void init(T)(T* v)
{
    static if (is (T == float))
    {
        *v = uniform(0.0f, 9_999_999.0f);
    }
    else static if (is(T == double))
    {
        *v = uniform(0.0, 9_999_999.0);
    }
    else static if (is(T == real))
    {
        *v = uniform(0.0L, 9_999_999.0L);
    }
    else
    {
        auto m = (cast(ubyte*) v)[0 .. T.sizeof];
        for(int i = 0; i < m.length; i++)
        {
            m[i] = uniform!byte;
        }
    }
}

void verify(T)(const T* a, const T* b)
{
    auto aa = (cast(ubyte*)a)[0..T.sizeof];
    auto bb = (cast(ubyte*)b)[0..T.sizeof];
    for(int i = 0; i < T.sizeof; i++)
    {
        assert(aa[i] == bb[i]);
    }
}

bool average;

void test(T)()
{
    // Just an arbitrarily sized buffer big enough to store test data
    // We will offset from this buffer to create unaligned data
    align(32) ubyte[66000] buf1;
    align(32) ubyte[66000] buf2;

    double TotalGBperSec1 = 0.0;
    double TotalGBperSec2 = 0.0;
    enum alignments = 16;

    // test align(0) through align(32) for now
    foreach(i; 0..alignments)
    {
        {
            static if (T.sizeof < 32)
            {
                T* d = cast(T*)(&buf1[i]);
                T* s = cast(T*)(&buf2[i]);
            }
            else // AVX code crashes on misalignment, so for now, always align(32)
            {
                T* d = cast(T*)(&buf1[0]);
                T* s = cast(T*)(&buf2[0]);
            }

            ulong bytesCopied1;
            ulong bytesCopied2;
            init(d);
            init(s);
            immutable d1 = benchmark!(T, memcpyC)(d, s, &bytesCopied1);
            verify(d, s);

            init(d);
            init(s);
            immutable d2 = benchmark!(T, memcpyD)(d, s, &bytesCopied2);
            verify(d, s);

            auto secs1 = (cast(double)(d1.total!"nsecs")) / 1_000_000_000.0;
            auto secs2 = (cast(double)(d2.total!"nsecs")) / 1_000_000_000.0;
            auto GB1 = (cast(double)bytesCopied1) / 1_000_000_000.0;
            auto GB2 = (cast(double)bytesCopied2) / 1_000_000_000.0;
            auto GBperSec1 = GB1 / secs1;
            auto GBperSec2 = GB2 / secs2;
            if (average)
            {
                TotalGBperSec1 += GBperSec1;
                TotalGBperSec2 += GBperSec2;
            }
            else
            {
                writeln(T.sizeof, " ", GBperSec1, " ", GBperSec2);
                stdout.flush();
            }
        }
    }

    if (average)
    {
        writeln(T.sizeof, " ", TotalGBperSec1 / alignments, " ", TotalGBperSec2 / alignments);
        stdout.flush();
    }
}


void main(string[] args)
{
    average = args.length >= 2;

    // For performing benchmarks
    writeln("size(bytes) memcpyC(GB/s) memcpyD(GB/s)");
    stdout.flush();
    static foreach(i; 1..17)
    {
        test!(S!i);
    }
    test!(S!32);
    test!(S!64);
    test!(S!128);
    test!(S!256);
    test!(S!512);
    test!(S!1024);
    test!(S!2048);
    test!(S!4096);
    test!(S!8192);
    test!(S!16384);
    test!(S!32768);
    test!(S!65536);

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
