/*# /=====================================================================\ #
  # |  LaTeXML/src/mouth.c                                                | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ #  */

/*======================================================================
  C-level Mouth support */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "errors.h"
#include "object.h"
#include "tokens.h"
#include "tokenstack.h"
#include "state.h"
#include "mouth.h"

void
mouth_setInput(pTHX_ SV * mouth, UTF8 input);

SV *
mouth_new(pTHX_ UTF8 class, UTF8 source, UTF8 short_source, UTF8 content,
          int saved_at_cc, int saved_comments, UTF8 note_message){
  LaTeXML_Mouth xmouth;
  Newxz(xmouth,1,T_Mouth);
  DEBUG_Mouth("Creating MOUTH for %s\n",source);
  Newxz(xmouth->chars,3,char);
  xmouth->bufsize = 3;
  xmouth->lineno  = 1;
  xmouth->pushback = tokenstack_new(aTHX);
  xmouth->source = string_copy(source);
  xmouth->short_source = string_copy(short_source);
  xmouth->saved_at_cc    = saved_at_cc;
  xmouth->saved_comments = saved_comments;
  xmouth->note_message   = (note_message ? string_copy(note_message) : NULL);
  xmouth->flags = (strcmp(source,"Anonymous String") == 0 ? 0 : MOUTH_INTERESTING);
  xmouth->previous_mouth = NULL;
  SV * mouth = newSV(0);
  sv_setref_pv(mouth, class, (void*)xmouth);
  mouth_setInput(aTHX_ mouth, content);
  return mouth; }

void
mouth_DESTROY(pTHX_ LaTeXML_Mouth xmouth){
  Safefree(xmouth->chars);
  Safefree(xmouth->source);
  Safefree(xmouth->short_source);
  Safefree(xmouth->note_message);  
  if(xmouth->previous_mouth){
    SvREFCNT_dec(xmouth->previous_mouth); }
  tokenstack_DESTROY(aTHX_ xmouth->pushback);
  Safefree(xmouth); }

void
mouth_finish(pTHX_ SV * mouth){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  LaTeXML_Tokenstack pb = xmouth->pushback;
  DEBUG_Mouth("Finished with Mouth for %s\n",xmouth->source);
  xmouth->lineno = 1;
  xmouth->colno  = 0;
  xmouth->nbytes = 0;
  xmouth->ptr    = 0;
  SV * state = state_global(aTHX);
  state_assign(aTHX_ state, TBL_CATCODE,"@", newSViv(xmouth->saved_at_cc),"local");
  state_assign(aTHX_ state, TBL_VALUE,"INCLUDE_COMMENTS", newSViv(xmouth->saved_comments),"local");
  while(pb->ntokens > 0){
    pb->ntokens--;
    SvREFCNT_dec(pb->tokens[pb->ntokens]); }
  if(xmouth->note_message){
    SV * message = newSVpv(xmouth->note_message,strlen(xmouth->note_message));
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,1); PUSHs(message);  PUTBACK;
    call_pv("NoteEnd",G_DISCARD);
    SPAGAIN; PUTBACK; FREETMPS; LEAVE;
  } }

#define CR 13
#define LF 10

void
mouth_setInput(pTHX_ SV * mouth, UTF8 input){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  xmouth->nbytes = strlen(input);
  DEBUG_Mouth("SET INPUT got %lu bytes: '%s'\n",xmouth->nbytes,input);
  if(xmouth->nbytes > xmouth->bufsize){ /* Check if buffer big enough. */
    if(xmouth->bufsize == 0){    /* first line? new buffer */
      Newx(xmouth->chars, (xmouth->nbytes + 2), char); }
    else {                    /* Else, grow if needed */
      Renew(xmouth->chars, (xmouth->nbytes + 2), char); }
    xmouth->bufsize = xmouth->nbytes; }
  CopyChar(input,xmouth->chars,xmouth->nbytes);
  /* Force the buffer to end with a CR */
  if((xmouth->nbytes > 0)
     && ! ((*(xmouth->chars+xmouth->nbytes -1) == CR)
           || (*(xmouth->chars+xmouth->nbytes -1) == LF))){
    *(xmouth->chars+xmouth->nbytes) = CR;
    xmouth->nbytes++; }
  xmouth->ptr    = 0;
  xmouth->colno  = 0;
  xmouth->lineno = 1;
  xmouth->flags  &= ~MOUTH_AT_EOF;
  xmouth->prev_ptr    = xmouth->ptr;
  xmouth->prev_colno  = xmouth->colno;
  xmouth->prev_lineno = xmouth->lineno;
}

int
mouth_hasMoreInput(pTHX_ SV * mouth){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  return (xmouth->pushback->ntokens > 0) || (xmouth->ptr < xmouth->nbytes); }

SV *
mouth_getLocator(pTHX_ SV * mouth){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  int l = xmouth->lineno;
  int c = xmouth->colno;
  /*
  if(length > 0){
    my $msg   = "at " . $self->getSource . "; line $l col $c";
    my $chars = $$self{chars};
    if (my $n = $$self{nchars}) {
      $c = $n - 1 if $c >= $n;
      my $c0 = ($c > 50      ? $c - 40 : 0);
      my $cm = ($c < 1       ? 0       : $c - 1);
      my $cn = ($n - $c > 50 ? $c + 40 : $n - 1);
      my $p1 = ($c0 <= $cm ? join('', @$chars[$c0 .. $cm]) : ''); chomp($p1);
      my $p2 = ($c <= $cn  ? join('', @$chars[$c .. $cn])  : ''); chomp($p2);
      $msg .= "\n  " . $p1 . "\n  " . (' ' x ($c - $c0)) . '^' . ' ' . $p2; }
    return $msg; }
    else { */
  SV * loc = newSV(0);
  sv_setpvf(loc,"at %s; line %d col %d",xmouth->source,l,c);
  return loc; }

  /* Since readToken looks ahead, we'll need to be able to undo the effects of mouth_readChar! */
int
mouth_readChar(pTHX_ SV * mouth, SV * state, char * character, int * catcode){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  if(xmouth->ptr < xmouth->nbytes){
    STRLEN ch_len;
    int nca = 0;                /* # chars advanced in buffer */
    int nba = 0;                /* # bytes advanced */
    int nbr = 0;                /* # bytes returned */
    char c;
    xmouth->prev_ptr = xmouth->ptr;
    xmouth->prev_colno = xmouth->colno;
    xmouth->prev_lineno = xmouth->lineno;
    DEBUG_Mouth("READCHAR @ %lu, %d x %lu\n", xmouth->ptr, xmouth->lineno, xmouth->colno);
    /* Check for line ends: CR+LF (Windows) | CR (Unix) | LF (old Mac);
       normalize to CR = \r = ^^M, which is what TeX expects. */
    if(((c = *(xmouth->chars+xmouth->ptr)) == CR) || (c == LF)){
      nba++; nca++;
      if((c == CR) && (xmouth->ptr + nba < xmouth->nbytes)
         && (*(xmouth->chars+xmouth->ptr+1) == LF)){ /* Got CRLF */
        nba++; nca++; }
      nbr = 1;
      DEBUG_Mouth(" succeeded w/CR\n");
      CopyChar("\r",character,1);      
      *catcode = state_catcode(aTHX_ state,character); /* But still, lookup current catcode! */
      xmouth->ptr += nba;
      xmouth->colno = 0;
      xmouth->lineno ++; }
    else {
      ch_len = UTF8SKIP(xmouth->chars+xmouth->ptr);
      CopyChar(xmouth->chars+xmouth->ptr,character,ch_len);
      DEBUG_Mouth("NEXT examine '%s', %lu bytes\n",character, ch_len);
      nca ++;
      nba += ch_len;
      nbr += ch_len;
      *catcode = state_catcode(aTHX_ state,character);
      if((*catcode == CC_SUPER)          /* Check for ^^hex or ^^<ctrl> */
         && (xmouth->ptr + nba + ch_len + 1 <= xmouth->nbytes)       /* at least 2 more chars? */
         && ( ((ch_len == 1) && (*character == *(xmouth->chars+xmouth->ptr+nba)))
              || (strncmp(character,xmouth->chars+xmouth->ptr + nba,ch_len)==0)) ){ /* check if same */
        DEBUG_Mouth("NEXT saw ^^\n");
        nba += ch_len;
        nca ++;
        /* Look for 2 lower-case hex or 1 control char (pure ASCII!) */
        char c1,c2, * tmp;
        UV code;
        if((xmouth->ptr + nba + 2 <= xmouth->nbytes)
           && (c1 = * (xmouth->chars+xmouth->ptr + nba))
           && ( ((c1 = c1-'0') >= 0) && ((c1 <= 9) || (((c1 = c1-'a'+'0'+10) >=10) && (c1 <= 15))))
           && (c2 = * (xmouth->chars+xmouth->ptr + nba + 1))
           && ( ((c2 = c2-'0') >= 0) && ((c2 <= 9) || (((c2 = c2-'a'+'0'+10) >=10) && (c2 <= 15)))) ){
          nba += 2;
          nca += 2;
          code = c1*16+c2; }
        else {
          c1 = * (xmouth->chars+xmouth->ptr + nba);
          nba ++;
          nca ++;
          code = (c1 > 64 ? c1 - 64 : c1 + 64); } /* ???? */
        /* Code point could have 8th bit, turn to multibyte unicode! */
        tmp = (char *)uvchr_to_utf8((U8 *)character,code);
        nbr = tmp - character;    /* how many bytes */
        *catcode = state_catcode(aTHX_ state,character); }
      DEBUG_Mouth("NEXT Succeed %d bytes, %d chars advanced => '%s', %d bytes\n",
                   nba,nca,character,nbr);
      xmouth->ptr += nba;
      xmouth->colno += nca; }
    return nbr; }
  else {
    DEBUG_Mouth("NEXT Failed\n");
    return 0; } }

  /* Put back the previously parsed character.  Would be nice to save it for next call,
     but the catcodes can (& will) change by then! */
void
mouth_unreadChar(pTHX_ SV * mouth){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  DEBUG_Mouth("PUTBack char\n");
  xmouth->ptr = xmouth->prev_ptr;
  xmouth->colno = xmouth->prev_colno;
  xmouth->lineno = xmouth->prev_lineno;
}

int
mouth_readLine(pTHX_ SV * mouth){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  STRLEN p = 0,pend;
  char c;
  /* Skip to CRLF|CR|LF */
  while((xmouth->ptr + p < xmouth->nbytes)
        && ( ( (c=*(xmouth->chars + xmouth->ptr + p)) != CR) && (c != LF)) ){
    p += UTF8SKIP(xmouth->chars + xmouth->ptr + p); }
  pend = p + 1;
  if((xmouth->ptr + pend < xmouth->nbytes)
     && (*(xmouth->chars + xmouth->ptr + pend - 1) == CR)
     && (*(xmouth->chars + xmouth->ptr + pend) == LF)){ /* CRLF */
    pend ++; }
  /* Now skip backwards over any trailing spaces */
  while(*(xmouth->chars + xmouth->ptr + p - 1) == ' ') {
    p--; }
  xmouth->ptr   += pend;
  xmouth->colno = 0;
  xmouth->lineno++;
  return p; }


/*
int
mouth_fetchInput(pTHX_ SV * mouth){
  int nvals;
  char * line;
  SV * sv;
  dSP;
  DEBUG_Mouth("FETCHLINE\n");
  ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(mouth);
  PUTBACK;
  nvals = call_method("getNextLine",G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    line = NULL; }
  else {
    sv = POPs;
    if(!SvOK(sv)){
      line = NULL; }
    else {
      if(! SvUTF8(sv)) {
        sv = sv_mortalcopy(sv);
        sv_utf8_upgrade(sv); }
      line = (UTF8)SvPV_nolen(sv);
      xmouth->nbytes = strlen(line);
      DEBUG_Mouth("FETCHLINE got %lu bytes: '%s'\n",xmouth->nbytes,line);
      if(xmouth->nbytes > xmouth->bufsize){
        if(xmouth->bufsize == 0){    
          Newx(xmouth->chars, (xmouth->nbytes + 1), char); }
        else {                   
          Renew(xmouth->chars, (xmouth->nbytes + 1), char); }
        xmouth->bufsize = xmouth->nbytes; }
      CopyChar(line,xmouth->chars,xmouth->nbytes);
      xmouth->ptr = 0; } }
  PUTBACK; FREETMPS; LEAVE;
  if(line == NULL){
    DEBUG_Mouth("No remaining input\n");
    xmouth->flags |= MOUTH_AT_EOF;
    return 0; }
  else {
    return 1; } }
*/

void
mouth_unreadToken(pTHX_ SV * mouth, SV * token){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  tokenstack_pushToken(aTHX_ xmouth->pushback, token); }

void
mouth_unread(pTHX_ SV * mouth, SV * thing){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  tokenstack_push(aTHX_ xmouth->pushback, thing); }


int CC_TrivialRead[] = 
  { 0, 1, 1, 1,
    1, 0, 1, 1,
    1, 0, 0, 1,
    1, 1, 0, 0,
    1, 1, 0};

SV *
mouth_readToken(pTHX_ SV * mouth, SV * state){
  LaTeXML_Mouth xmouth = SvMouth(mouth);
  char ch[UTF8_MAXBYTES+1];
  int  cc;
  STRLEN nbytes;
  STRLEN startcol = xmouth->colno;
  if(xmouth->pushback->ntokens > 0){
    return tokenstack_pop(aTHX_ xmouth->pushback); }
  while(1){
    DEBUG_Mouth("READ Token @ %lu\n",startcol);
    if((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc))){
      if((startcol == 0) && (cc == CC_SPACE)){ /* Ignore leading spaces */
        DEBUG_Mouth("Skipping leading space\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc) && (cc == CC_SPACE))){
        } }
      if(CC_TrivialRead[cc]){   /* Common, trivial case first */
        DEBUG_Mouth("Token[%s,%s]\n",ch,CC_SHORT_NAME[cc]);
        return token_new(aTHX_ ch,cc); }
      else if(cc == CC_ESCAPE){
        /* WARNING: Actually, room for the whole file!
           What's a SAFE strategy for reasonable max token length??? */
        char buffer[xmouth->nbytes+1]; /* room for whole line. */
        STRLEN p;
        buffer[0]='\\'; p = 1; buffer[p]=0; /* Store \, 'cause CS are stored that way */
        DEBUG_Mouth("ESCAPE '%s'\n",buffer);
          if((nbytes = mouth_readChar(aTHX_ mouth,state,buffer+p,&cc))){
          p+=nbytes;
          if(cc == CC_LETTER){
            while((nbytes = mouth_readChar(aTHX_ mouth,state,buffer+p,&cc)) && (cc == CC_LETTER)){
              p+=nbytes; }
            *(buffer+p)=0;    /* terminate the CS, in case we just added a non-letter */
            /* if peeked char was space, skip spaces */
            while((cc == CC_SPACE) && (nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc)) ){
            }
            /* In \read & we get EOL, we'll put it back to turn into a space; otherwise remove it */
            if ((cc == CC_EOL) && !(state_lookupIV(aTHX_ state, TBL_VALUE, "PRESERVE_NEWLINES") > 1)) {
              nbytes = 0; }    /* so it will NOT be put back  */
            if(nbytes) {        /* put back last non-letter, non-space peeked char, if any */
              mouth_unreadChar(aTHX_ mouth); } }
        }
        else {
          croak("Missing character following escape char %s",ch); }
        DEBUG_Mouth("Token[%s,%s]\n",buffer,CC_SHORT_NAME[CC_CS]);
        return token_new(aTHX_ buffer,CC_CS); }
      else if (cc == CC_SPACE){
        int cr = 0;
        DEBUG_Mouth("Skipping spaces\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc)) /* skip following spaces */
              && ((cc == CC_SPACE) || (cc == CC_EOL)) ){
          if(cc == CC_EOL){
            cr = 1;
            nbytes = 0;
            break; } }
        if(nbytes){           /* put back non-space (if any) */
          mouth_unreadChar(aTHX_ mouth); }
        if(cr && state_lookupIV(aTHX_ state, TBL_VALUE, "PRESERVE_NEWLINES")){
          return token_new(aTHX_ "\n",CC_SPACE); }
        else {
          return token_new(aTHX_ " ",CC_SPACE); } }
      else if (cc == CC_COMMENT){
        STRLEN pstart = xmouth->ptr;
        STRLEN n;
        if((n = mouth_readLine(aTHX_ mouth))
           && state_lookupBoole(aTHX_ state,TBL_VALUE,"INCLUDE_COMMENTS")){
          char buffer[n+2];
          buffer[0]='%';            
          Copy(xmouth->chars+pstart,buffer+1,n,char);
          buffer[n+1] = 0;
          DEBUG_Mouth("Comment '%s'\n",buffer);
          return token_new(aTHX_ buffer,cc);
        }
        startcol = xmouth->colno; }
      else if (cc == CC_EOL){
        if(startcol == 0){
          DEBUG_Mouth("EOL \\par\n");
          return T_CS("\\par"); }
        else if(state_lookupIV(aTHX_ state,TBL_VALUE, "PRESERVE_NEWLINES")){
          DEBUG_Mouth("EOL T_SPACE[\\n]\n");
          return token_new(aTHX_ "\n",CC_SPACE); }
        else {
          DEBUG_Mouth("EOL T_SPACE\n");
          return token_new(aTHX_ " ",CC_SPACE); } }
      else if (cc == CC_IGNORE){
        DEBUG_Mouth("IGNORE\n"); }
      else if (cc == CC_INVALID){
        DEBUG_Mouth("INVALID\n");
        return token_new(aTHX_ ch,CC_OTHER); } /* ? */
      else {
        DEBUG_Mouth("No proper Catcode '%d'\n",cc); }
      }
    else {                    /* Got no input; Try for next line. */
      /* Comment this out; it currently has no effect, but we may want to "chunk" input???
      if(! mouth_fetchInput(aTHX_ mouth)){
      break; } */                /* EXIT FROM OUTER LOOP */
      xmouth->flags |= MOUTH_AT_EOF;        /* but still terminate */
      return NULL;
      /* This should be integrated into above; CC_EOL ? CC_COMMENT ? 
      if(((xmouth->lineno % 25) == 0) && state_lookupBoole(aTHX_ state,TBL_VALUE,"INCLUDE_COMMENTS")){
        char * source = mouth_getShortsource(aTHX_ mouth);
        if(source != NULL){
          char * comment = form("**** %s Line %d ****",source,xmouth->lineno);
          token = token_new(aTHX_ comment, CC_COMMENT); } }
      else {
      startcol = xmouth->colno; } */
    } } }

SV *
mouth_readTokens(pTHX_ SV * mouth, SV * state, SV * until){
  SV * tokens = tokens_new(aTHX_ 1);
  LaTeXML_Token u = (until ? SvToken(until) : NULL);
  char * test = (u ? u->string : NULL);
  SV * token;
  /* NOTE: Compare to Until's string, NOT catcode!! */
  while ( (token = mouth_readToken(aTHX_ mouth, state)) ) {
    LaTeXML_Token t = SvToken(token);
    if(test && (strcmp(test,t->string) == 0)){
      SvREFCNT_dec(token);
      break; }
    tokens_add_token(aTHX_ tokens,token);
    SvREFCNT_dec(token); }
  tokens_trimright(aTHX_ tokens);
  return tokens; }
