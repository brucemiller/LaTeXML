\RequirePackage{xkeyval}

\def\@boolean{}
\define@boolkey{xkvdop5.cls}[cls]{bool}{\edef\@boolean{#1, \@boolean}}
\def\boolean{\ifclsbool true\else false\fi\ (\@boolean)}
\ProcessOptionsX

\LoadClass{article}