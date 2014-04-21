;;; parser-macros.scm
;;; Defines any parser macros that may be useful in parsing literate scheme
;;; files.

(load-option '*parser)

(define-*parser-macro (delimited-block delimiter type)
  `(seq #\[ ,delimiter
        (values ,type)
        (match
           (* (alt (not-char ,delimiter)
                   (seq (char ,delimiter)
                        (not-char #\])) )))
        ,delimiter #\]))

