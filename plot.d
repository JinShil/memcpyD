module plot;

import std.process;
import std.string;
import std.stdio: writeln;
import std.file;

class ExitException : Exception
{
    int status;

    @safe pure nothrow this(int status, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.status = status;
    }
}

string run(string cmd)
{
    auto x = executeShell(cmd);
    if (x.status != 0)
    {
        throw new ExitException(x.status);
    }

    return x.output;
}

int main(string[] args)
{
    try
    {
        immutable os = run(`uname -o`).replace("\n", "");
        immutable processor = run(`cat /proc/cpuinfo | grep -m 1 "model name"`).replace("model name\t: ", "").replace("\n","");

        immutable title = os ~ ", " ~ processor;
        run(`gnuplot -persist <<EOF
            set title"` ~ title ~ `"
            set autoscale
            set logscale x 2
            set xlabel 'size in bytes'
            set ylabel 'GB/s'
            set terminal qt size 900,480
            plot '` ~ args[1] ~ `' using "size(bytes)":"memcpyC(GB/s)" with lines, '' using "size(bytes)":"memcpyD(GB/s)" with lines
            `);
    }
    catch(ExitException e)
    {
        return e.status;
    }

    return 0;
}