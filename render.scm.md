Extended markdown rendering in Scheme
=====================================

It can often be useful to embed LaTeX diagrams, graphs, and so on inside an
`lp.scm` document you are writing.  One can generate these files separately and
link them manually, but then you end up with `.tex` files and the like scattered
all over the place, many of which express a single small equation!  Not to
mention keeping track of which source belongs to which part of the document can
be extremely difficult.

Since we already have the REPL open to parse and run the document we're working
with, why not supply a simple render procedure to generate images from code
embedded in the markdown file itself?  That is the purpose of this module.

This module is written as a literate Scheme file; to make use of it you will
need to use `lp.scm` as follows:

    (load "lp.scm")
    (load-literate "render.scm.md")

This will give you access to the `lp_render` procedure to render embedded LaTeX.
For example, running this script on itself will generate the images below:

    (lp/render "render.scm.md")

Example images
--------------

Take a look at the source for this markdown document to see what the embedded
markup for each image kind looks like.

### Embedded LaTeX

![$ Some embedded \LaTeX{} including some maths: $e = mc^2$ $](img/latex.png?raw=true)

### Normal images work as usual

![Normal images still work](http://www.disqorse.com/uploads/monthly_02_2014/post-1-0-81204300-1393096566.jpg)

Load options and entry point definition
---------------------------------------

This module makes use of a couple of extensions specific to MIT Scheme:
\*parser language definitions and synchronous subprocesses.  The former gives us
a simple parser combinator library which makes it much easier to read the input,
while the latter lets us call shell commands.  These extensions need to be
enabled, which can be done using `load-option`:

```scheme
(load-option '*parser)
(load-option 'synchronous-subprocess)
```

The module exports a single procedure, `lp/render`.  Everything else is defined
within this procedure to avoid cluttering up the namespace with utility
functions.

```scheme
(define (lp/render filename)
```

`lp/render` will take a single parameter, the filename to parse for embedded
markup.  It will go through the file, looking for supported markup, and generate
images from that markup.  Currently supported markup is:

 * `![$ ... $]`, where the dots represent some LaTeX code

This markup must be followed be the image filename to output in brackets (which
has to be a `png` file).  The perspicacious reader will have noticed that this
syntax is a variation on standard markdown image syntax.  This is no
coincidence!  This keeps the file compatible with standard markdown and ensures
that markdown viewers will be able to display the resulting images.

> Tip: If the file is intended to be viewed on Github, you'll need to put
> `?raw=true` at the end of the image filename.  The renderer strips anything
> after the question mark out of the filename, so the output file will still
> have the correct name, but the image source as viewed on github will include
> it.  Unfortunately, this means that markdown files that look good on github
> won't display images when viewed locally, and vice versa.

TODO list
---------

There are a few issues with this module that still need to be resolved.  These
are as follows:

  * Make a parser\* macro parse-delimited-block to replace parse-latex-block
  * Add support for graphs/diagrams with Python's matplotlib
  * Deal properly with the final latex block (breaks unless there is a
    non-markup bang somewhere between there and the end of the file at the
    moment)

Parser combinators
-------------------------

Parser combinators provide an intuitive approach to building parsers, whereby
complex parsers can be constructed by composing simple parsers together.  It is
especially popular in the [Haskell][haskell] community, where parser combinator
libraries like [Parsec][parsec] really demonstrate the power of this model.

MIT Scheme's [Parser Language][parser-language] provides a similar sort of
functionality by using lisp macros.  The combinators provided by the library are
fairly limited in scope, but the idea is that by combining these and abstracting
common patterns using parser-language macros, you can design quite powerful
parsers.

We begin with an overview of what it is we'd like to achieve.  The
`parse-extended-markup` procedure will parse a single block of extended markup,
from the `![` opening to the close of the image filename (`)`).

```scheme
  (define parse-extended-markup
    (*parser
      (seq parse-latex-block
           skip-whitespace
           parse-image-filename)))
```

The parser is fairly straightforward and provides a good summary of what is to
come.  `*parser` returns a parser, which expects a single argument (the parser
buffer, which we'll talk about a bit later).  `seq` is a utility function
provided by the parser-language module which sequences a set of parsers
together, concatenating their results.  The rest reads like a description of
what we'd like to do: first parse the extended markup block, skip any whitespace
between that and the image, and then parse the image filename.  The meat of our
parser will take place in the definition of these procedures.

Skipping text
-------------

The simplest form of parser simply skips over text, taking us to the next part
of the file we might actually be interested in.  `parse-extended-markup`
contains one such parser, which skips whitespace between the embedded markup and
the image filename.  We will also need another, to skip everything until we
reach the next `!` symbol, ready to start parsing the next block of extended
markdown

The parser-language provides a few tools to help us here:

  * `noise` runs the provided `matcher`, moving the buffer forward and throwing
    away the result.
  * `*` works similarly to the regex primitive -- it matches zero or more of the
    provided `matcher`.
  * `char` matches a single, provided character, while `not-char` matches
    anything *other* than the provided character.
  * `char-set` matches any character within the supplied [character set][character-sets].

Putting that all together, we get:

```scheme
  (define skip-whitespace
    (*parser (noise (* (char-set char-set:whitespace)))))

  (define skip-to-bang
    (*parser (seq (noise (* (not-char #\!))) #\!)))
```

Notice that these definitions also begin `*parser`.  This is what gives the
parser-language its composability: The macro both takes and returns a parser, as
does its utility functions such as `seq`.  By making use of this mechanism,
complex parsers can be constructed from simple, modular components.

Parsing the actual content
--------------------------

There are two pieces of content we're interested in: the extended markdown and
the name of the image to output to.  I'm going to begin with the image parser
since that's simple.

```scheme
  (define parse-image-filename
    (*parser (seq #\( (match (* (not-char #\)))) #\))))
```

Here we're not supporting a `)` character in the image path, which seems
reasonable.  As you can see, we make use of `seq` to combine three parsers: two
for the parentheses on either side and one for the actual filename itself.  The
filename is defined as simply "any character which isn't `)`".  We'll handle
things like the `?raw=true` suffix later; for now we just pass it through as if
it's part of the string.

When using a raw character or string literal (such as `#\(` and `#\)` above) in
a parser, parser-language will implicitly wrap it in `noise`, throwing away the
result.  If you need it included in the parsed output you can make use of the
`char` or `string` parsers, so `(char #\()` will match and return a `(`
character.  We make use of this in the parser for LaTeX blocks.

```
  (define parse-latex-block
    (*parser
      (seq #\[ #\$
           (values 'latex)
           (match
             (* (alt (not-char #\$)
                     (seq (char #\$)
                          (not-char #\])) )))
           #\$ #\])))
```

This parser is a little more complicated, so let's break it down slowly.  We
know our latex blocks are delimited by special `[$` and `$]` brackets, so we
need to parse these (discarding the result) at the beginning and the end of our
parser.  The plan is to support various kinds of embedded markup, so we'd like
to be able to include arbitrary information about what sort of markup this is in
the output of the parser; this is the role of the `values` combinator, which
performs no actual parsing but simply always succeeds, adding its parameter to
the results of the parse.

Finally, we're left with the `match` clause.  The reason this is tricky is that
we need to support instances of the `$` character being used inside the LaTeX
source itself -- it is the delimiter for maths environments in LaTeX, which is
the main reason we wanted to embed LaTeX in the first place!  In order to
achieve this, we want to be able to match the following:

 * Any character that is *not* `$`
 * Any instance of `$` that is not immediately followed by `]`

This will allow us to match `$` but not `$]`, which is what we want.  In order
to express alternatives like this, we can use the parser-language's `alt`
primitive, which attempts a series of parsers in turn, backtracking to the
starting point and trying again if they fail, and returning the results of the
first fully successful parse.  The first alternative is simple: if the character
is not `$`, just let it straight through.  The second alternative must check two
characters, so we combine the `char` and `not-char` parsers using the `seq`
primitive.  We want the parsed values to be included in the result (otherwise
all `$` signs in the embedded LaTeX would be filtered out!), so we use a `char`
parser rather than just writing the raw literal.  Finally we string all these
characters together using `*`.

The bulk of the parsing work is complete.  There is just one problem -- you may
have noticed that all parsers thus far have assumed they are in the right place
to begin parsing the thing they were meant to parse.  We will thus need a way to
link them together, skipping over the text we aren't interested in to get to the
parts we are.  We can make use of the `skip-to-bang` parser we wrote earlier to
achieve this:

```scheme
  (define parse-extended-or-skip
    (*parser
      (seq (? parse-extended-markup)
           skip-to-bang)))
```

There is a hidden subtlety here.  The `?` operator, similar to the regular
expressions operator by the same name, parses 0 or 1 instances of the provided
parser.  Why is it necessary here?  Consider what would happen when the text
contains an exclamation character which does not form part of an extended
markdown block; for example a simple exclamation mark at the end of a sentence.
`skip-to-bang` would put us where we want to be, immediately after it, but then
`parse-extended-markup` would attempt to parse the `[$ ... $]` block following
it and fail, causing the whole parser to fail and stop processing the file.
What we actually want is simply to skip to the next `!` character in this
situation.

An aside: generalising the `parse-latex-block` parser
-----------------------------------------------------

We are likely to want to support more than just embedded LaTeX.  It would be
nice to embed graphs or other generated images in the file as well.  We could
write a procedure for each, for example `parse-matplotlib-block`,
`parse-imagemagick-block`, and so on but we know the structure of these things
is going to be quite similar, so ideally we'd like to be able to abstract this
to a single procedure which takes a delimiter and a type (`$` and `'latex` in
the above case), and parses a block of that type.  We could then alternate
between these using `alt`.

Parser-language provides a method to do this in the form of [parser-language macros][plm],
and future versions of this module will use exactly this functionality to create
a `parse-delimited-block` macro.  Unfortunately, I haven't managed to get that
working yet, so for now we will continue to use the `parse-latex-block`
procedure.

> Note: The following is my attempt to define a \*parser macro as described
> above, but it doesn't work at present.  When it does, I will rewrite the above
> explanation.

```scheme
  (define-*parser-macro (delimited-block delimiter type)
      `(seq #\[ ,delimiter
            (values ,type)
            (match
              (* (alt (not-char ,delimiter)
                      (seq (char ,delimiter)
                           (not-char #\])) )))
            ,delimiter #\]))

  (define parse-latex-block (*parser (delimited-block #\$ 'latex)))
  (define parse-dot-block   (*parser (delimited-block #\. 'dot)))
```

Extracting the markup
---------------------

Using the above parser combinators, we can extract a list of all valid markup
from a file.  We want to loop over a supplied parser buffer, calling
`parse-extended-or-skip`, and then add any returned values to a list of results.
When the parser returns false, that means we have finished processing the file.

```scheme
  (define (extract-markup-from-buffer buf)
    (let loop ((p   (parse-extended-or-skip buf))
               (acc (list)))
      (if (not p)
          acc
          (loop (parse-extended-or-skip buf)
                (if (> (vector-length p) 0)
                    (cons p acc)
                    acc)))))
```

This procedure works more or less as you might expect; the only slight surprise
is the inner `if` expression.  Why is that necessary?  Well, remember when we
defined `parse-extended-or-skip` we used the `?` primitive to say "Attempt to
parse an extended block, but if there isn't one that's fine, just skip to the
next `!` character".  It's the "that's fine" that's key here --
`parse-extended-markup` may have failed, but `(? parse-extended-markup)`
actually parsed *successfully*, returning an empty result!  We want to discard
these results, so we just check the resulting results vector to make sure it
actually has content before adding it to the list.

Now all we need to do is actually run the procedure on our file!  Recall that we
are still within the scope of the `lp/render` definition, so we have access to
the `filename` variable passed as a parameter.  We can thus read the markup as
follows:

```scheme
  (define extracted-markup
    (call-with-input-file filename
      (lambda (f)
        (port/set-coding f 'utf-8)
        (extract-markup-from-buffer (input-port->parser-buffer f)))))
```

Parsers expect a "parser buffer", which is a buffered form of input that they
use for backtracking.  The parser-language provides a number of converters to
help create these buffers, including `input-port->parser-buffer` which we use
above.  If we were parsing from a string rather than a file, we could simply use
`string->parser-buffer` instead.

Generating the images
---------------------

OK, so now we have all the data we need: we know the *filenames* of the images
that need to be created, the *source* used to create them, and what type of source
it is, which will determine the *method* by which we create them.  In general,
these images will not be generated by Scheme; instead, we will call other
utilities to create them from the provided source.  Of course, this module will
only work if the required utilities are installed on the machine you are running
it on!

At a high level, we simply want to loop over all the blocks extracted from the
file, processing each one.  Scheme provides a higher-order procedure for
performing a side effect on each element of a list, namely `for-each`:

```scheme
  (define (process-all)
    (for-each process extracted-markup))
```

This procedure looks very similar to the better-known `map` function, and indeed
it is basically the same, however there are a couple of differences:

 * `for-each` is guaranteed to run through the list in order; `map` may process
   it in any order it pleases.
 * `map` is intended to be run to modify the members of the list it's passed,
   and thus its return value is a modified list.  `for-each` is intended to be
   run for its side effects, so it's return value is unspecified.

In reality, in many implementations the procedures are exactly the same as it is
easy to implement `for-each` in terms of `map`; however, this is not guaranteed,
and it is better to use `map` when you want to modify a list and `for-each` when
you want to perform side effects.  Even if the results would be equivalent,
using the appropriate functions at the right time helps to communicate your
intention to other programmers, which is at least as important as getting the
job done in the first place.

Digging down a little bit, what form does the `process` procedure take?

```scheme
  (define (process block)
    (let ((type (vector-first block))
          (src  (vector-second block))
          (img  (normalise-image-filename (vector-third  block))))
      (cond
        ((equal? type 'latex) (process-latex src img)))))
```

This is fairly simple; we simply extract the parts we're interested in out of
the block, and then run the appropriate processor on it.  We are using a `cond`
statement to switch on the block type, which is fine as there aren't going to be
many different types supported.  An alternative if there are lots of types is to
construct a lookup table from block type to processor procedure, but that would
be overkill in this case.

`normalise-image-filename` is run on the images to strip of everything after
the `?` character in the case where we have added `?raw=true` or similar for
display on Github.  We could have done this as part of the parser, but it is
possible we might want to do something with this data in the future so we chose
to let it through then and strip it out here.  The procedure to remove it is
quite simple; we search for instances of the `?` character and take the
substring to that point:

```scheme
  (define (normalise-image-filename img)
    (let ((idx (string-find-next-char img #\?)))
      (if idx (substring img 0 idx) img)))
```

Now all that remains is to write the procedures which do the actual processing.

Generating embedded LaTeX images
--------------------------------

All processors take two parameters, the source code from which to generate the
image, and the filename to output to:

```scheme
  (define (process-latex src img)
```

The LaTeX processor in particular has two requirements:

 * A LaTeX installation (including `pdflatex`)
 * A program to convert `pdf` files to `png`

MIT Scheme provides a procedure,  `run-synchronous-subprocess`, which will run a
shell command, outputting anything it outputs to `STDOUT`, and returning to the
REPL when the command has completed.  We'll use it to write procedures we can
use to run the two programs we need.

```scheme
    (define (run-pdflatex dir texfile)
      (run-synchronous-subprocess
        "pdflatex" (list (string "--output-directory=" dir) texfile)))
```

Which image converter to use depends on which platform we're running.  On Mac OS
X, the program used for image conversion is `sips`, which comes as standard.
Otherwise, we'll try ImageMagick.

> Note: I'm switching on the operating system here, but really I should probably
> switch on availability of the executable using `which` or similar.

```scheme
    (define (run-image-converter pdf img)
      (if (equal? microcode-id/operating-system-variant "MacOSX")
        (run-synchronous-subprocess
          "sips" (list "-s" "format" "png" "--out" img pdf))
        (run-synchronous-subprocess "convert" (list pdf img))))
```

We want the user to be able to embed quite concise LaTeX snippets, so we'll
create a template which will wrap whatever source they provide in some standard
LaTeX boilerplate:

```scheme
    (define (write-latex-document p)
      (display
        (string "\\documentclass[border=1]{standalone}"
                "\\usepackage{amsmath,amsthm,amssymb}"
                "\\begin{document}"
                src
                "\\end{document}") p))
```

Finally we write the actual generation procedure which takes a filename for the
temporary LaTeX file it will use to generate the image, writes out the LaTeX
source, and converts it.  Since LaTeX generates quite a lot of temporary files
as it does its work, we delete those files as well before we're done.

```scheme
    (define (gen-latex f)
      (call-with-output-file f write-latex-document)
      (let* ((tmpdir (directory-namestring f ))
             (tmptex (->namestring f))
             (tmppdf (string tmptex ".pdf"))
             (tmplog (string tmptex ".log"))
             (tmpaux (string tmptex ".aux"))
             (outdir (directory-namestring img)))
        (if (not (file-exists? outdir)) (make-directory outdir))
        (run-pdflatex tmpdir tmptex)
        (run-image-converter tmppdf img)
        (delete-file tmplog)
        (delete-file tmpaux)
        (delete-file tmppdf)))
```

This may look quite complicated, but look closely and you'll see that it mostly
does the same thing; generating the names of intermediate files we know LaTeX
will spit out as part of its processing, and deleting those files afterwards.
Functions like `->namestring` take a `pathname`, a platform-independent
representation of the file path, and return a string describing that path on the
platform we're running on.  `call-with-output-file` opens an output port and
calls the provided procedure, passing that port as its only parameter.  It also
ensures the port gets closed properly when the procedure is complete, or in case
of error.

The final step in the `process-latex` procedure is to generate a temporary file
to write the LaTeX to, and then call `gen-latex` on that file.  For this we can
use `call-with-temporary-file-pathname`, which generates a temporary file and
calls the provided procedure, passing the pathname as a parameter.  When the
procedure is complete, the temporary file is deleted.

```scheme
    (call-with-temporary-file-pathname gen-latex))
```

Note that the extra parenthesis here closes the scope we introduced with
`(define (process-latex src img)` at the beginning of this section.

Wrapping up
-----------

The final step is to actually call the `process-all` procedure we defined above,
which will go through all the extended markup we've found in the file and run
the appropriate processor on it.  We then close the final scope, and our
`lp/render` procedure is ready to use!

```scheme
  (process-all))
```

[dpwright/sicp]:   https://github.com/dpwright/sicp
[haskell]:         http://www.haskell.org
[parsec]:          http://hackage.haskell.org/package/parsec
[parser-language]: http://www.gnu.org/software/mit-scheme/documentation/mit-scheme-ref/Parser-Language.html#Parser-Language
[plm]:             http://www.gnu.org/software/mit-scheme/documentation/mit-scheme-ref/Parser_002dlanguage-Macros.html#Parser_002dlanguage-Macros
[character-sets]:  http://www.gnu.org/software/mit-scheme/documentation/mit-scheme-ref/Character-Sets.html
