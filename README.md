lp.scm
======

`lp.scm` adds [literate programming][lp] support to MIT-Scheme.

It was developed because I decided to work through [Structure and Interpretation
of Computer Programs][sicp] recently and I wanted to write my answers in a
literate style.  There are quite a lot of tools out there to do this, but I
wanted something integrated into scheme so that I could just load a literate
file at the REPL and it would "just work".

Usage
-----

Usage is pretty simple: write your source files in github-flavoured markdown,
putting any code you want to be loaded into scheme-highlighted fenced code
blocks:

    ```scheme
    ; This will be loaded
    (+ 4 5)
    ````

    This won't be loaded.

    ```
    Neither will this
    ```

At the REPL, first load the script:

    (load "lp.scm")

Then, where you would usually call `(load "foo.scm")`, replace `load` with
`load-literate`, i.e.

    (load-literate "foo.scm.md")

That's it!

Known Issues
------------

I pretty much cobbled this together to suit my purposes, so the implementation
is pretty naïve, but it should do the job.  In particular, it loads the (code
portions of) the entire file into memory at once before evaluating them, so it
may fall over on really (very) large files.  I expect a better approach would be
to create a kind of port that can skip over non-code portions of the file, but I
don't know how to do that in scheme.  Maybe I'll rewrite it better when I finish
the book!  Or you can send me a pull request.

Because I have done this specifically for SICP, I am using MIT Scheme, and
that's all I've tested with.  I think the functions I've used are all pretty
portable though, so hopefully it should work with other schemes too.

Licence
-------

Released under the BSD3 licence; see LICENCE for details.

Copyright (c) Daniel P. Wright 2014.

[lp]:   http://en.wikipedia.org/wiki/Literate_programming
[sicp]: http://mitpress.mit.edu/sicp/
