# /=====================================================================\ #
# |  Precompiled $style.bst                                             | #
# |  for LaTeXML                                                        | #
# |=====================================================================| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
# THIS IS A GENERATED FILE! DO NOT EDIT
package LaTeXML::BibTeX::BibStyle::Precompiled;
use strict;
use warnings;
use LaTeXML::BibTeX::BibStyle::StyCommand;
use LaTeXML::BibTeX::BibStyle::StyString;
sub Cmd { return LaTeXML::BibTeX::BibStyle::StyCommand->new(@_); }
sub Nmb { return LaTeXML::BibTeX::BibStyle::StyString->new('NUMBER',    @_); }
sub Quo { return LaTeXML::BibTeX::BibStyle::StyString->new('QUOTE',     @_); }
sub Lit { return LaTeXML::BibTeX::BibStyle::StyString->new('LITERAL',   @_); }
sub Ref { return LaTeXML::BibTeX::BibStyle::StyString->new('REFERENCE', @_); }
sub Blk { return LaTeXML::BibTeX::BibStyle::StyString->new('BLOCK',     @_); }
our $DEFAULT;
$DEFAULT = [Cmd('ENTRY', [Blk([Lit('address'), Lit('author'), Lit('booktitle'), Lit('chapter'), Lit('edition'), Lit('editor'), Lit('howpublished'), Lit('institution'), Lit('journal'), Lit('key'), Lit('month'), Lit('note'), Lit('number'), Lit('organization'), Lit('pages'), Lit('publisher'), Lit('school'), Lit('series'), Lit('title'), Lit('type'), Lit('volume'), Lit('year')]), Blk([]), Blk([Lit('label')])]), Cmd('INTEGERS', [Blk([Lit('output.state'), Lit('before.all'), Lit('mid.sentence'), Lit('after.sentence'), Lit('after.block')])]), Cmd('FUNCTION', [Blk([Lit('init.state.consts')]), Blk([Nmb('0'), Ref('before.all'), Lit(':='), Nmb('1'), Ref('mid.sentence'), Lit(':='), Nmb('2'), Ref('after.sentence'), Lit(':='), Nmb('3'), Ref('after.block'), Lit(':=')])]), Cmd('STRINGS', [Blk([Lit('s'), Lit('t')])]), Cmd('FUNCTION', [Blk([Lit('output.nonnull')]), Blk([Ref('s'), Lit(':='), Lit('output.state'), Lit('mid.sentence'), Lit('='), Blk([Quo(', '), Lit('*'), Lit('write$')]), Blk([Lit('output.state'), Lit('after.block'), Lit('='), Blk([Lit('add.period$'), Lit('write$'), Lit('newline$'), Quo('\newblock '), Lit('write$')]), Blk([Lit('output.state'), Lit('before.all'), Lit('='), Ref('write$'), Blk([Lit('add.period$'), Quo(' '), Lit('*'), Lit('write$')]), Lit('if$')]), Lit('if$'), Lit('mid.sentence'), Ref('output.state'), Lit(':=')]), Lit('if$'), Lit('s')])]), Cmd('FUNCTION', [Blk([Lit('output')]), Blk([Lit('duplicate$'), Lit('empty$'), Ref('pop$'), Ref('output.nonnull'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('output.check')]), Blk([Ref('t'), Lit(':='), Lit('duplicate$'), Lit('empty$'), Blk([Lit('pop$'), Quo('empty '), Lit('t'), Lit('*'), Quo(' in '), Lit('*'), Lit('cite$'), Lit('*'), Lit('warning$')]), Ref('output.nonnull'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('output.bibitem')]), Blk([Lit('newline$'), Quo('\bibitem{'), Lit('write$'), Lit('cite$'), Lit('write$'), Quo('}'), Lit('write$'), Lit('newline$'), Quo(''), Lit('before.all'), Ref('output.state'), Lit(':=')])]), Cmd('FUNCTION', [Blk([Lit('fin.entry')]), Blk([Lit('add.period$'), Lit('write$'), Lit('newline$')])]), Cmd('FUNCTION', [Blk([Lit('new.block')]), Blk([Lit('output.state'), Lit('before.all'), Lit('='), Ref('skip$'), Blk([Lit('after.block'), Ref('output.state'), Lit(':=')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('new.sentence')]), Blk([Lit('output.state'), Lit('after.block'), Lit('='), Ref('skip$'), Blk([Lit('output.state'), Lit('before.all'), Lit('='), Ref('skip$'), Blk([Lit('after.sentence'), Ref('output.state'), Lit(':=')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('not')]), Blk([Blk([Nmb('0')]), Blk([Nmb('1')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('and')]), Blk([Ref('skip$'), Blk([Lit('pop$'), Nmb('0')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('or')]), Blk([Blk([Lit('pop$'), Nmb('1')]), Ref('skip$'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('new.block.checka')]), Blk([Lit('empty$'), Ref('skip$'), Ref('new.block'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('new.block.checkb')]), Blk([Lit('empty$'), Lit('swap$'), Lit('empty$'), Lit('and'), Ref('skip$'), Ref('new.block'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('new.sentence.checka')]), Blk([Lit('empty$'), Ref('skip$'), Ref('new.sentence'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('new.sentence.checkb')]), Blk([Lit('empty$'), Lit('swap$'), Lit('empty$'), Lit('and'), Ref('skip$'), Ref('new.sentence'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('field.or.null')]), Blk([Lit('duplicate$'), Lit('empty$'), Blk([Lit('pop$'), Quo('')]), Ref('skip$'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('emphasize')]), Blk([Lit('duplicate$'), Lit('empty$'), Blk([Lit('pop$'), Quo('')]), Blk([Quo('{\em '), Lit('swap$'), Lit('*'), Quo('}'), Lit('*')]), Lit('if$')])]), Cmd('INTEGERS', [Blk([Lit('nameptr'), Lit('namesleft'), Lit('numnames')])]), Cmd('FUNCTION', [Blk([Lit('format.names')]), Blk([Ref('s'), Lit(':='), Nmb('1'), Ref('nameptr'), Lit(':='), Lit('s'), Lit('num.names$'), Ref('numnames'), Lit(':='), Lit('numnames'), Ref('namesleft'), Lit(':='), Blk([Lit('namesleft'), Nmb('0'), Lit('>')]), Blk([Lit('s'), Lit('nameptr'), Quo('{ff~}{vv~}{ll}{, jj}'), Lit('format.name$'), Ref('t'), Lit(':='), Lit('nameptr'), Nmb('1'), Lit('>'), Blk([Lit('namesleft'), Nmb('1'), Lit('>'), Blk([Quo(', '), Lit('*'), Lit('t'), Lit('*')]), Blk([Lit('numnames'), Nmb('2'), Lit('>'), Blk([Quo(','), Lit('*')]), Ref('skip$'), Lit('if$'), Lit('t'), Quo('others'), Lit('='), Blk([Quo(' et~al.'), Lit('*')]), Blk([Quo(' and '), Lit('*'), Lit('t'), Lit('*')]), Lit('if$')]), Lit('if$')]), Ref('t'), Lit('if$'), Lit('nameptr'), Nmb('1'), Lit('+'), Ref('nameptr'), Lit(':='), Lit('namesleft'), Nmb('1'), Lit('-'), Ref('namesleft'), Lit(':=')]), Lit('while$')])]), Cmd('FUNCTION', [Blk([Lit('format.authors')]), Blk([Lit('author'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('author'), Lit('format.names')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.editors')]), Blk([Lit('editor'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('editor'), Lit('format.names'), Lit('editor'), Lit('num.names$'), Nmb('1'), Lit('>'), Blk([Quo(', editors'), Lit('*')]), Blk([Quo(', editor'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.title')]), Blk([Lit('title'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('title'), Quo('t'), Lit('change.case$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('n.dashify')]), Blk([Ref('t'), Lit(':='), Quo(''), Blk([Lit('t'), Lit('empty$'), Lit('not')]), Blk([Lit('t'), Nmb('1'), Nmb('1'), Lit('substring$'), Quo('-'), Lit('='), Blk([Lit('t'), Nmb('1'), Nmb('2'), Lit('substring$'), Quo('--'), Lit('='), Lit('not'), Blk([Quo('--'), Lit('*'), Lit('t'), Nmb('2'), Lit('global.max$'), Lit('substring$'), Ref('t'), Lit(':=')]), Blk([Blk([Lit('t'), Nmb('1'), Nmb('1'), Lit('substring$'), Quo('-'), Lit('=')]), Blk([Quo('-'), Lit('*'), Lit('t'), Nmb('2'), Lit('global.max$'), Lit('substring$'), Ref('t'), Lit(':=')]), Lit('while$')]), Lit('if$')]), Blk([Lit('t'), Nmb('1'), Nmb('1'), Lit('substring$'), Lit('*'), Lit('t'), Nmb('2'), Lit('global.max$'), Lit('substring$'), Ref('t'), Lit(':=')]), Lit('if$')]), Lit('while$')])]), Cmd('FUNCTION', [Blk([Lit('format.date')]), Blk([Lit('year'), Lit('empty$'), Blk([Lit('month'), Lit('empty$'), Blk([Quo('')]), Blk([Quo('there\'s a month but no year in '), Lit('cite$'), Lit('*'), Lit('warning$'), Lit('month')]), Lit('if$')]), Blk([Lit('month'), Lit('empty$'), Ref('year'), Blk([Lit('month'), Quo(' '), Lit('*'), Lit('year'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.btitle')]), Blk([Lit('title'), Lit('emphasize')])]), Cmd('FUNCTION', [Blk([Lit('tie.or.space.connect')]), Blk([Lit('duplicate$'), Lit('text.length$'), Nmb('3'), Lit('<'), Blk([Quo('~')]), Blk([Quo(' ')]), Lit('if$'), Lit('swap$'), Lit('*'), Lit('*')])]), Cmd('FUNCTION', [Blk([Lit('either.or.check')]), Blk([Lit('empty$'), Ref('pop$'), Blk([Quo('can\'t use both '), Lit('swap$'), Lit('*'), Quo(' fields in '), Lit('*'), Lit('cite$'), Lit('*'), Lit('warning$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.bvolume')]), Blk([Lit('volume'), Lit('empty$'), Blk([Quo('')]), Blk([Quo('volume'), Lit('volume'), Lit('tie.or.space.connect'), Lit('series'), Lit('empty$'), Ref('skip$'), Blk([Quo(' of '), Lit('*'), Lit('series'), Lit('emphasize'), Lit('*')]), Lit('if$'), Quo('volume and number'), Lit('number'), Lit('either.or.check')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.number.series')]), Blk([Lit('volume'), Lit('empty$'), Blk([Lit('number'), Lit('empty$'), Blk([Lit('series'), Lit('field.or.null')]), Blk([Lit('output.state'), Lit('mid.sentence'), Lit('='), Blk([Quo('number')]), Blk([Quo('Number')]), Lit('if$'), Lit('number'), Lit('tie.or.space.connect'), Lit('series'), Lit('empty$'), Blk([Quo('there\'s a number but no series in '), Lit('cite$'), Lit('*'), Lit('warning$')]), Blk([Quo(' in '), Lit('*'), Lit('series'), Lit('*')]), Lit('if$')]), Lit('if$')]), Blk([Quo('')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.edition')]), Blk([Lit('edition'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('output.state'), Lit('mid.sentence'), Lit('='), Blk([Lit('edition'), Quo('l'), Lit('change.case$'), Quo(' edition'), Lit('*')]), Blk([Lit('edition'), Quo('t'), Lit('change.case$'), Quo(' edition'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('INTEGERS', [Blk([Lit('multiresult')])]), Cmd('FUNCTION', [Blk([Lit('multi.page.check')]), Blk([Ref('t'), Lit(':='), Nmb('0'), Ref('multiresult'), Lit(':='), Blk([Lit('multiresult'), Lit('not'), Lit('t'), Lit('empty$'), Lit('not'), Lit('and')]), Blk([Lit('t'), Nmb('1'), Nmb('1'), Lit('substring$'), Lit('duplicate$'), Quo('-'), Lit('='), Lit('swap$'), Lit('duplicate$'), Quo(','), Lit('='), Lit('swap$'), Quo('+'), Lit('='), Lit('or'), Lit('or'), Blk([Nmb('1'), Ref('multiresult'), Lit(':=')]), Blk([Lit('t'), Nmb('2'), Lit('global.max$'), Lit('substring$'), Ref('t'), Lit(':=')]), Lit('if$')]), Lit('while$'), Lit('multiresult')])]), Cmd('FUNCTION', [Blk([Lit('format.pages')]), Blk([Lit('pages'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('pages'), Lit('multi.page.check'), Blk([Quo('pages'), Lit('pages'), Lit('n.dashify'), Lit('tie.or.space.connect')]), Blk([Quo('page'), Lit('pages'), Lit('tie.or.space.connect')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.vol.num.pages')]), Blk([Lit('volume'), Lit('field.or.null'), Lit('number'), Lit('empty$'), Ref('skip$'), Blk([Quo('('), Lit('number'), Lit('*'), Quo(')'), Lit('*'), Lit('*'), Lit('volume'), Lit('empty$'), Blk([Quo('there\'s a number but no volume in '), Lit('cite$'), Lit('*'), Lit('warning$')]), Ref('skip$'), Lit('if$')]), Lit('if$'), Lit('pages'), Lit('empty$'), Ref('skip$'), Blk([Lit('duplicate$'), Lit('empty$'), Blk([Lit('pop$'), Lit('format.pages')]), Blk([Quo(':'), Lit('*'), Lit('pages'), Lit('n.dashify'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.chapter.pages')]), Blk([Lit('chapter'), Lit('empty$'), Ref('format.pages'), Blk([Lit('type'), Lit('empty$'), Blk([Quo('chapter')]), Blk([Lit('type'), Quo('l'), Lit('change.case$')]), Lit('if$'), Lit('chapter'), Lit('tie.or.space.connect'), Lit('pages'), Lit('empty$'), Ref('skip$'), Blk([Quo(', '), Lit('*'), Lit('format.pages'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.in.ed.booktitle')]), Blk([Lit('booktitle'), Lit('empty$'), Blk([Quo('')]), Blk([Lit('editor'), Lit('empty$'), Blk([Quo('In '), Lit('booktitle'), Lit('emphasize'), Lit('*')]), Blk([Quo('In '), Lit('format.editors'), Lit('*'), Quo(', '), Lit('*'), Lit('booktitle'), Lit('emphasize'), Lit('*')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('empty.misc.check')]), Blk([Lit('author'), Lit('empty$'), Lit('title'), Lit('empty$'), Lit('howpublished'), Lit('empty$'), Lit('month'), Lit('empty$'), Lit('year'), Lit('empty$'), Lit('note'), Lit('empty$'), Lit('and'), Lit('and'), Lit('and'), Lit('and'), Lit('and'), Lit('key'), Lit('empty$'), Lit('not'), Lit('and'), Blk([Quo('all relevant fields are empty in '), Lit('cite$'), Lit('*'), Lit('warning$')]), Ref('skip$'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.thesis.type')]), Blk([Lit('type'), Lit('empty$'), Ref('skip$'), Blk([Lit('pop$'), Lit('type'), Quo('t'), Lit('change.case$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.tr.number')]), Blk([Lit('type'), Lit('empty$'), Blk([Quo('Technical Report')]), Ref('type'), Lit('if$'), Lit('number'), Lit('empty$'), Blk([Quo('t'), Lit('change.case$')]), Blk([Lit('number'), Lit('tie.or.space.connect')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.article.crossref')]), Blk([Lit('key'), Lit('empty$'), Blk([Lit('journal'), Lit('empty$'), Blk([Quo('need key or journal for '), Lit('cite$'), Lit('*'), Quo(' to crossref '), Lit('*'), Lit('crossref'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Quo('In {\em '), Lit('journal'), Lit('*'), Quo('\/}'), Lit('*')]), Lit('if$')]), Blk([Quo('In '), Lit('key'), Lit('*')]), Lit('if$'), Quo(' \cite{'), Lit('*'), Lit('crossref'), Lit('*'), Quo('}'), Lit('*')])]), Cmd('FUNCTION', [Blk([Lit('format.crossref.editor')]), Blk([Lit('editor'), Nmb('1'), Quo('{vv~}{ll}'), Lit('format.name$'), Lit('editor'), Lit('num.names$'), Lit('duplicate$'), Nmb('2'), Lit('>'), Blk([Lit('pop$'), Quo(' et~al.'), Lit('*')]), Blk([Nmb('2'), Lit('<'), Ref('skip$'), Blk([Lit('editor'), Nmb('2'), Quo('{ff }{vv }{ll}{ jj}'), Lit('format.name$'), Quo('others'), Lit('='), Blk([Quo(' et~al.'), Lit('*')]), Blk([Quo(' and '), Lit('*'), Lit('editor'), Nmb('2'), Quo('{vv~}{ll}'), Lit('format.name$'), Lit('*')]), Lit('if$')]), Lit('if$')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('format.book.crossref')]), Blk([Lit('volume'), Lit('empty$'), Blk([Quo('empty volume in '), Lit('cite$'), Lit('*'), Quo('\'s crossref of '), Lit('*'), Lit('crossref'), Lit('*'), Lit('warning$'), Quo('In ')]), Blk([Quo('Volume'), Lit('volume'), Lit('tie.or.space.connect'), Quo(' of '), Lit('*')]), Lit('if$'), Lit('editor'), Lit('empty$'), Lit('editor'), Lit('field.or.null'), Lit('author'), Lit('field.or.null'), Lit('='), Lit('or'), Blk([Lit('key'), Lit('empty$'), Blk([Lit('series'), Lit('empty$'), Blk([Quo('need editor, key, or series for '), Lit('cite$'), Lit('*'), Quo(' to crossref '), Lit('*'), Lit('crossref'), Lit('*'), Lit('warning$'), Quo(''), Lit('*')]), Blk([Quo('{\em '), Lit('*'), Lit('series'), Lit('*'), Quo('\/}'), Lit('*')]), Lit('if$')]), Blk([Lit('key'), Lit('*')]), Lit('if$')]), Blk([Lit('format.crossref.editor'), Lit('*')]), Lit('if$'), Quo(' \cite{'), Lit('*'), Lit('crossref'), Lit('*'), Quo('}'), Lit('*')])]), Cmd('FUNCTION', [Blk([Lit('format.incoll.inproc.crossref')]), Blk([Lit('editor'), Lit('empty$'), Lit('editor'), Lit('field.or.null'), Lit('author'), Lit('field.or.null'), Lit('='), Lit('or'), Blk([Lit('key'), Lit('empty$'), Blk([Lit('booktitle'), Lit('empty$'), Blk([Quo('need editor, key, or booktitle for '), Lit('cite$'), Lit('*'), Quo(' to crossref '), Lit('*'), Lit('crossref'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Quo('In {\em '), Lit('booktitle'), Lit('*'), Quo('\/}'), Lit('*')]), Lit('if$')]), Blk([Quo('In '), Lit('key'), Lit('*')]), Lit('if$')]), Blk([Quo('In '), Lit('format.crossref.editor'), Lit('*')]), Lit('if$'), Quo(' \cite{'), Lit('*'), Lit('crossref'), Lit('*'), Quo('}'), Lit('*')])]), Cmd('FUNCTION', [Blk([Lit('article')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Lit('crossref'), Lit('missing$'), Blk([Lit('journal'), Lit('emphasize'), Quo('journal'), Lit('output.check'), Lit('format.vol.num.pages'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check')]), Blk([Lit('format.article.crossref'), Lit('output.nonnull'), Lit('format.pages'), Lit('output')]), Lit('if$'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('book')]), Blk([Lit('output.bibitem'), Lit('author'), Lit('empty$'), Blk([Lit('format.editors'), Quo('author and editor'), Lit('output.check')]), Blk([Lit('format.authors'), Lit('output.nonnull'), Lit('crossref'), Lit('missing$'), Blk([Quo('author and editor'), Lit('editor'), Lit('either.or.check')]), Ref('skip$'), Lit('if$')]), Lit('if$'), Lit('new.block'), Lit('format.btitle'), Quo('title'), Lit('output.check'), Lit('crossref'), Lit('missing$'), Blk([Lit('format.bvolume'), Lit('output'), Lit('new.block'), Lit('format.number.series'), Lit('output'), Lit('new.sentence'), Lit('publisher'), Quo('publisher'), Lit('output.check'), Lit('address'), Lit('output')]), Blk([Lit('new.block'), Lit('format.book.crossref'), Lit('output.nonnull')]), Lit('if$'), Lit('format.edition'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('booklet')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Lit('output'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('howpublished'), Lit('address'), Lit('new.block.checkb'), Lit('howpublished'), Lit('output'), Lit('address'), Lit('output'), Lit('format.date'), Lit('output'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('inbook')]), Blk([Lit('output.bibitem'), Lit('author'), Lit('empty$'), Blk([Lit('format.editors'), Quo('author and editor'), Lit('output.check')]), Blk([Lit('format.authors'), Lit('output.nonnull'), Lit('crossref'), Lit('missing$'), Blk([Quo('author and editor'), Lit('editor'), Lit('either.or.check')]), Ref('skip$'), Lit('if$')]), Lit('if$'), Lit('new.block'), Lit('format.btitle'), Quo('title'), Lit('output.check'), Lit('crossref'), Lit('missing$'), Blk([Lit('format.bvolume'), Lit('output'), Lit('format.chapter.pages'), Quo('chapter and pages'), Lit('output.check'), Lit('new.block'), Lit('format.number.series'), Lit('output'), Lit('new.sentence'), Lit('publisher'), Quo('publisher'), Lit('output.check'), Lit('address'), Lit('output')]), Blk([Lit('format.chapter.pages'), Quo('chapter and pages'), Lit('output.check'), Lit('new.block'), Lit('format.book.crossref'), Lit('output.nonnull')]), Lit('if$'), Lit('format.edition'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('incollection')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Lit('crossref'), Lit('missing$'), Blk([Lit('format.in.ed.booktitle'), Quo('booktitle'), Lit('output.check'), Lit('format.bvolume'), Lit('output'), Lit('format.number.series'), Lit('output'), Lit('format.chapter.pages'), Lit('output'), Lit('new.sentence'), Lit('publisher'), Quo('publisher'), Lit('output.check'), Lit('address'), Lit('output'), Lit('format.edition'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check')]), Blk([Lit('format.incoll.inproc.crossref'), Lit('output.nonnull'), Lit('format.chapter.pages'), Lit('output')]), Lit('if$'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('inproceedings')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Lit('crossref'), Lit('missing$'), Blk([Lit('format.in.ed.booktitle'), Quo('booktitle'), Lit('output.check'), Lit('format.bvolume'), Lit('output'), Lit('format.number.series'), Lit('output'), Lit('format.pages'), Lit('output'), Lit('address'), Lit('empty$'), Blk([Lit('organization'), Lit('publisher'), Lit('new.sentence.checkb'), Lit('organization'), Lit('output'), Lit('publisher'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check')]), Blk([Lit('address'), Lit('output.nonnull'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.sentence'), Lit('organization'), Lit('output'), Lit('publisher'), Lit('output')]), Lit('if$')]), Blk([Lit('format.incoll.inproc.crossref'), Lit('output.nonnull'), Lit('format.pages'), Lit('output')]), Lit('if$'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('conference')]), Blk([Lit('inproceedings')])]), Cmd('FUNCTION', [Blk([Lit('manual')]), Blk([Lit('output.bibitem'), Lit('author'), Lit('empty$'), Blk([Lit('organization'), Lit('empty$'), Ref('skip$'), Blk([Lit('organization'), Lit('output.nonnull'), Lit('address'), Lit('output')]), Lit('if$')]), Blk([Lit('format.authors'), Lit('output.nonnull')]), Lit('if$'), Lit('new.block'), Lit('format.btitle'), Quo('title'), Lit('output.check'), Lit('author'), Lit('empty$'), Blk([Lit('organization'), Lit('empty$'), Blk([Lit('address'), Lit('new.block.checka'), Lit('address'), Lit('output')]), Ref('skip$'), Lit('if$')]), Blk([Lit('organization'), Lit('address'), Lit('new.block.checkb'), Lit('organization'), Lit('output'), Lit('address'), Lit('output')]), Lit('if$'), Lit('format.edition'), Lit('output'), Lit('format.date'), Lit('output'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('mastersthesis')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Quo('Master\'s thesis'), Lit('format.thesis.type'), Lit('output.nonnull'), Lit('school'), Quo('school'), Lit('output.check'), Lit('address'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('misc')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Lit('output'), Lit('title'), Lit('howpublished'), Lit('new.block.checkb'), Lit('format.title'), Lit('output'), Lit('howpublished'), Lit('new.block.checka'), Lit('howpublished'), Lit('output'), Lit('format.date'), Lit('output'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry'), Lit('empty.misc.check')])]), Cmd('FUNCTION', [Blk([Lit('phdthesis')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.btitle'), Quo('title'), Lit('output.check'), Lit('new.block'), Quo('PhD thesis'), Lit('format.thesis.type'), Lit('output.nonnull'), Lit('school'), Quo('school'), Lit('output.check'), Lit('address'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('proceedings')]), Blk([Lit('output.bibitem'), Lit('editor'), Lit('empty$'), Blk([Lit('organization'), Lit('output')]), Blk([Lit('format.editors'), Lit('output.nonnull')]), Lit('if$'), Lit('new.block'), Lit('format.btitle'), Quo('title'), Lit('output.check'), Lit('format.bvolume'), Lit('output'), Lit('format.number.series'), Lit('output'), Lit('address'), Lit('empty$'), Blk([Lit('editor'), Lit('empty$'), Blk([Lit('publisher'), Lit('new.sentence.checka')]), Blk([Lit('organization'), Lit('publisher'), Lit('new.sentence.checkb'), Lit('organization'), Lit('output')]), Lit('if$'), Lit('publisher'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check')]), Blk([Lit('address'), Lit('output.nonnull'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.sentence'), Lit('editor'), Lit('empty$'), Ref('skip$'), Blk([Lit('organization'), Lit('output')]), Lit('if$'), Lit('publisher'), Lit('output')]), Lit('if$'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('techreport')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Lit('format.tr.number'), Lit('output.nonnull'), Lit('institution'), Quo('institution'), Lit('output.check'), Lit('address'), Lit('output'), Lit('format.date'), Quo('year'), Lit('output.check'), Lit('new.block'), Lit('note'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('unpublished')]), Blk([Lit('output.bibitem'), Lit('format.authors'), Quo('author'), Lit('output.check'), Lit('new.block'), Lit('format.title'), Quo('title'), Lit('output.check'), Lit('new.block'), Lit('note'), Quo('note'), Lit('output.check'), Lit('format.date'), Lit('output'), Lit('fin.entry')])]), Cmd('FUNCTION', [Blk([Lit('default.type')]), Blk([Lit('misc')])]), Cmd('MACRO', [Blk([Lit('jan')]), Blk([Quo('January')])]), Cmd('MACRO', [Blk([Lit('feb')]), Blk([Quo('February')])]), Cmd('MACRO', [Blk([Lit('mar')]), Blk([Quo('March')])]), Cmd('MACRO', [Blk([Lit('apr')]), Blk([Quo('April')])]), Cmd('MACRO', [Blk([Lit('may')]), Blk([Quo('May')])]), Cmd('MACRO', [Blk([Lit('jun')]), Blk([Quo('June')])]), Cmd('MACRO', [Blk([Lit('jul')]), Blk([Quo('July')])]), Cmd('MACRO', [Blk([Lit('aug')]), Blk([Quo('August')])]), Cmd('MACRO', [Blk([Lit('sep')]), Blk([Quo('September')])]), Cmd('MACRO', [Blk([Lit('oct')]), Blk([Quo('October')])]), Cmd('MACRO', [Blk([Lit('nov')]), Blk([Quo('November')])]), Cmd('MACRO', [Blk([Lit('dec')]), Blk([Quo('December')])]), Cmd('MACRO', [Blk([Lit('acmcs')]), Blk([Quo('ACM Computing Surveys')])]), Cmd('MACRO', [Blk([Lit('acta')]), Blk([Quo('Acta Informatica')])]), Cmd('MACRO', [Blk([Lit('cacm')]), Blk([Quo('Communications of the ACM')])]), Cmd('MACRO', [Blk([Lit('ibmjrd')]), Blk([Quo('IBM Journal of Research and Development')])]), Cmd('MACRO', [Blk([Lit('ibmsj')]), Blk([Quo('IBM Systems Journal')])]), Cmd('MACRO', [Blk([Lit('ieeese')]), Blk([Quo('IEEE Transactions on Software Engineering')])]), Cmd('MACRO', [Blk([Lit('ieeetc')]), Blk([Quo('IEEE Transactions on Computers')])]), Cmd('MACRO', [Blk([Lit('ieeetcad')]), Blk([Quo('IEEE Transactions on Computer-Aided Design of Integrated Circuits')])]), Cmd('MACRO', [Blk([Lit('ipl')]), Blk([Quo('Information Processing Letters')])]), Cmd('MACRO', [Blk([Lit('jacm')]), Blk([Quo('Journal of the ACM')])]), Cmd('MACRO', [Blk([Lit('jcss')]), Blk([Quo('Journal of Computer and System Sciences')])]), Cmd('MACRO', [Blk([Lit('scp')]), Blk([Quo('Science of Computer Programming')])]), Cmd('MACRO', [Blk([Lit('sicomp')]), Blk([Quo('SIAM Journal on Computing')])]), Cmd('MACRO', [Blk([Lit('tocs')]), Blk([Quo('ACM Transactions on Computer Systems')])]), Cmd('MACRO', [Blk([Lit('tods')]), Blk([Quo('ACM Transactions on Database Systems')])]), Cmd('MACRO', [Blk([Lit('tog')]), Blk([Quo('ACM Transactions on Graphics')])]), Cmd('MACRO', [Blk([Lit('toms')]), Blk([Quo('ACM Transactions on Mathematical Software')])]), Cmd('MACRO', [Blk([Lit('toois')]), Blk([Quo('ACM Transactions on Office Information Systems')])]), Cmd('MACRO', [Blk([Lit('toplas')]), Blk([Quo('ACM Transactions on Programming Languages and Systems')])]), Cmd('MACRO', [Blk([Lit('tcs')]), Blk([Quo('Theoretical Computer Science')])]), Cmd('READ', []), Cmd('FUNCTION', [Blk([Lit('sortify')]), Blk([Lit('purify$'), Quo('l'), Lit('change.case$')])]), Cmd('INTEGERS', [Blk([Lit('len')])]), Cmd('FUNCTION', [Blk([Lit('chop.word')]), Blk([Ref('s'), Lit(':='), Ref('len'), Lit(':='), Lit('s'), Nmb('1'), Lit('len'), Lit('substring$'), Lit('='), Blk([Lit('s'), Lit('len'), Nmb('1'), Lit('+'), Lit('global.max$'), Lit('substring$')]), Ref('s'), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('sort.format.names')]), Blk([Ref('s'), Lit(':='), Nmb('1'), Ref('nameptr'), Lit(':='), Quo(''), Lit('s'), Lit('num.names$'), Ref('numnames'), Lit(':='), Lit('numnames'), Ref('namesleft'), Lit(':='), Blk([Lit('namesleft'), Nmb('0'), Lit('>')]), Blk([Lit('nameptr'), Nmb('1'), Lit('>'), Blk([Quo('   '), Lit('*')]), Ref('skip$'), Lit('if$'), Lit('s'), Lit('nameptr'), Quo('{vv{ } }{ll{ }}{  ff{ }}{  jj{ }}'), Lit('format.name$'), Ref('t'), Lit(':='), Lit('nameptr'), Lit('numnames'), Lit('='), Lit('t'), Quo('others'), Lit('='), Lit('and'), Blk([Quo('et al'), Lit('*')]), Blk([Lit('t'), Lit('sortify'), Lit('*')]), Lit('if$'), Lit('nameptr'), Nmb('1'), Lit('+'), Ref('nameptr'), Lit(':='), Lit('namesleft'), Nmb('1'), Lit('-'), Ref('namesleft'), Lit(':=')]), Lit('while$')])]), Cmd('FUNCTION', [Blk([Lit('sort.format.title')]), Blk([Ref('t'), Lit(':='), Quo('A '), Nmb('2'), Quo('An '), Nmb('3'), Quo('The '), Nmb('4'), Lit('t'), Lit('chop.word'), Lit('chop.word'), Lit('chop.word'), Lit('sortify'), Nmb('1'), Lit('global.max$'), Lit('substring$')])]), Cmd('FUNCTION', [Blk([Lit('author.sort')]), Blk([Lit('author'), Lit('empty$'), Blk([Lit('key'), Lit('empty$'), Blk([Quo('to sort, need author or key in '), Lit('cite$'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Lit('key'), Lit('sortify')]), Lit('if$')]), Blk([Lit('author'), Lit('sort.format.names')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('author.editor.sort')]), Blk([Lit('author'), Lit('empty$'), Blk([Lit('editor'), Lit('empty$'), Blk([Lit('key'), Lit('empty$'), Blk([Quo('to sort, need author, editor, or key in '), Lit('cite$'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Lit('key'), Lit('sortify')]), Lit('if$')]), Blk([Lit('editor'), Lit('sort.format.names')]), Lit('if$')]), Blk([Lit('author'), Lit('sort.format.names')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('author.organization.sort')]), Blk([Lit('author'), Lit('empty$'), Blk([Lit('organization'), Lit('empty$'), Blk([Lit('key'), Lit('empty$'), Blk([Quo('to sort, need author, organization, or key in '), Lit('cite$'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Lit('key'), Lit('sortify')]), Lit('if$')]), Blk([Quo('The '), Nmb('4'), Lit('organization'), Lit('chop.word'), Lit('sortify')]), Lit('if$')]), Blk([Lit('author'), Lit('sort.format.names')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('editor.organization.sort')]), Blk([Lit('editor'), Lit('empty$'), Blk([Lit('organization'), Lit('empty$'), Blk([Lit('key'), Lit('empty$'), Blk([Quo('to sort, need editor, organization, or key in '), Lit('cite$'), Lit('*'), Lit('warning$'), Quo('')]), Blk([Lit('key'), Lit('sortify')]), Lit('if$')]), Blk([Quo('The '), Nmb('4'), Lit('organization'), Lit('chop.word'), Lit('sortify')]), Lit('if$')]), Blk([Lit('editor'), Lit('sort.format.names')]), Lit('if$')])]), Cmd('FUNCTION', [Blk([Lit('presort')]), Blk([Lit('type$'), Quo('book'), Lit('='), Lit('type$'), Quo('inbook'), Lit('='), Lit('or'), Ref('author.editor.sort'), Blk([Lit('type$'), Quo('proceedings'), Lit('='), Ref('editor.organization.sort'), Blk([Lit('type$'), Quo('manual'), Lit('='), Ref('author.organization.sort'), Ref('author.sort'), Lit('if$')]), Lit('if$')]), Lit('if$'), Quo('    '), Lit('*'), Lit('year'), Lit('field.or.null'), Lit('sortify'), Lit('*'), Quo('    '), Lit('*'), Lit('title'), Lit('field.or.null'), Lit('sort.format.title'), Lit('*'), Nmb('1'), Lit('entry.max$'), Lit('substring$'), Ref('sort.key$'), Lit(':=')])]), Cmd('ITERATE', [Blk([Lit('presort')])]), Cmd('SORT', []), Cmd('STRINGS', [Blk([Lit('longest.label')])]), Cmd('INTEGERS', [Blk([Lit('number.label'), Lit('longest.label.width')])]), Cmd('FUNCTION', [Blk([Lit('initialize.longest.label')]), Blk([Quo(''), Ref('longest.label'), Lit(':='), Nmb('1'), Ref('number.label'), Lit(':='), Nmb('0'), Ref('longest.label.width'), Lit(':=')])]), Cmd('FUNCTION', [Blk([Lit('longest.label.pass')]), Blk([Lit('number.label'), Lit('int.to.str$'), Ref('label'), Lit(':='), Lit('number.label'), Nmb('1'), Lit('+'), Ref('number.label'), Lit(':='), Lit('label'), Lit('width$'), Lit('longest.label.width'), Lit('>'), Blk([Lit('label'), Ref('longest.label'), Lit(':='), Lit('label'), Lit('width$'), Ref('longest.label.width'), Lit(':=')]), Ref('skip$'), Lit('if$')])]), Cmd('EXECUTE', [Blk([Lit('initialize.longest.label')])]), Cmd('ITERATE', [Blk([Lit('longest.label.pass')])]), Cmd('FUNCTION', [Blk([Lit('begin.bib')]), Blk([Lit('preamble$'), Lit('empty$'), Ref('skip$'), Blk([Lit('preamble$'), Lit('write$'), Lit('newline$')]), Lit('if$'), Quo('\begin{thebibliography}{'), Lit('longest.label'), Lit('*'), Quo('}'), Lit('*'), Lit('write$'), Lit('newline$')])]), Cmd('EXECUTE', [Blk([Lit('begin.bib')])]), Cmd('EXECUTE', [Blk([Lit('init.state.consts')])]), Cmd('ITERATE', [Blk([Lit('call.type$')])]), Cmd('FUNCTION', [Blk([Lit('end.bib')]), Blk([Lit('newline$'), Quo('\end{thebibliography}'), Lit('write$'), Lit('newline$')])]), Cmd('EXECUTE', [Blk([Lit('end.bib')])])];
1;
