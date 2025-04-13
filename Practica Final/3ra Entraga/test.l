(setq a 1) 

 (defun main ()
(setq a 0)
 (loop while (/= a 10) do 
(princ a )
 (setq a (+ a 1))
 )
)
