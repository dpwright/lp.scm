;;; lp.scm
;;; Adds support for loading programs written in a literate style to MIT-Scheme.
;;; Assumes the input is in github-flavoured markdown, and that scheme sections
;;; use language-specific code blocks (i.e. "```scheme").
;;; The idea is that if you load this file first, you get a "load-literate"
;;; function which will extract the scheme blocks from a markdown file and
;;; evaluate them, so you can use it like you would "load".

(define (load-literate filename #!optional environment)
  (define (extract-fenced-blocks filename)
    (define (main-reader line lines)
      (cond ((string=? line "```scheme") (cons scheme-block-reader     lines))
            ((string=? line "```")       (cons non-scheme-block-reader lines))
            (else                        (cons main-reader             lines))))
    (define (non-scheme-block-reader line lines)
      (cond ((string=? line "```")       (cons main-reader             lines))
            (else                        (cons non-scheme-block-reader lines))))
    (define (scheme-block-reader line lines)
      (define (strip-comments line)
        (let ((idx (string-find-next-char line #\;)))
          (if idx (substring line 0 idx) line)))

      (cond ((string=? line "```")       (cons main-reader             lines))
            (else                        (cons scheme-block-reader
                                               (cons (strip-comments line) lines)))))

    (call-with-input-file filename
      (lambda (p)
        (let loop ((reader main-reader)
                   (line   (read-line p))
                   (lines  (list)))
          (if (eof-object? line)
                (reverse lines)
                (let ((result (reader line lines)))
                  (loop (car result) (read-line p) (cdr result))))))))

  (let ((environment (if (default-object? environment)
                         (current-load-environment)
                         (->environment environment))))
    (call-with-input-string
      (apply string-append (extract-fenced-blocks filename))
      (lambda (p)
        (let loop ((sexpr     (read p environment))
                   (rtn-value (if #f #t)))
          (if (eof-object? sexpr)
            rtn-value
            (loop (read p environment)
                  (eval sexpr environment) )))))))
