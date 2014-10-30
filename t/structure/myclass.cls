% Declaration of options
\def\my@class@stuff{}

\DeclareOption{acommonoption}{\xdef\my@class@stuff{\my@class@stuff,acommonoption}}
\DeclareOption{aclassoption}{\xdef\my@class@stuff{\my@class@stuff,aclassoption}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
% Execution of options
\ProcessOptions
% package loading
\LoadClass{article}

% main code
\def\showclassstuff{\par\noindent Class options: \my@class@stuff}
