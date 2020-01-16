# BiBTeX subsytem

This folder contains files the main chunk of the BiBTeX subsystem of LaTeXML. 
This system is a pure-perl efficient parser, compiler and interpreter for [BibTeX](http://www.bibtex.org) `.bib` and `.bst` files. 

As such it can:
* read BibTeX `.bib` bibliography files
* compile BibTeX `.bst` bibliography style files into perl
* output BiBTeX `.bbl` in a machine-readable format, maintaining source references of substrings

This subsytem was originally called `BiBTeXML` and developed seperatly to replace the existing `BiBTeX` handling of [LaTeXML](https://dlmf.nist.gov/LaTeXML/)by Tom Wiesing. 

## How it works

The BiBTeX subsytem is split into (roughly) four components:

* [`BibStyle`](BibStyle/) - a parser for `.bst` files
* [`Compiler`](Compiler/) - a compiler for `.bst` files into perl

* [`Runtime`](Runtime/) - a (perl only) runtime for the compiler-generated code
* [`Bibliography`](Bibliography/) - a parser for `.bib` files

### Implementation Notes

This code faithfully emulates BibTeX and should produce output that is character-by-character identical to BiBTeX itself -- everything else is considered a bug. There are two notable exceptions:
- It allows keeping track of source references and insert a wrapping macro. This is disabled by default. 
- It does not emulate BiBTeX's wrapped output by default. If emulation of this behavior is desired (e.g. during the tests), one can optionally pass the `--wrap` option to the appropriate commands to perform the hard wrapping. 

## How to use

The system can be used independently of LaTeXML. 
This independent mode consists of two different stages, which can be run either together or seperatly. 
The stages are:
- Compilation stage: Compiles a `.bst` file into executable perl code
- Runtime stage: Runs the compiled `bst` code to emulate what `BiBTeX` does

### Running both stages together

To run everything together use the `tools/bibtexml` program.
It has the following syntax:

```
bibtexml [--help] [--wrap] [--destination $DEST] [--cites $CITES] [--macro $MACRO] $BSTFILE $BIBFILE [$BIBFILE ...]
```

- `$DEST` is the name of the output file to write output to. If omitted, output is sent to `STDOUT`. 
- `$CITES` is a comma-separated set of keys of entries that are assumed to have been cited. Defaults to the special '*' key, which assumes that all entries have been cited. 
- `$MACRO` is a macro to wrap all source references in. If omitted, source references are not shown in the output. 
- `$BSTFILE` is the (absolute or relative to the working directory) path to the `.bst` file to compile. 
- `$BIBFILE` is the name of a bibfile to include. 
- `--wrap` enables emulating BiBTeX's output wrapping. 


### Running the compilation stage

This stage reads and compiles the `.bst` file. 
In general, this can be done achieved using `tools/bibtexmlc` ( *c* as in *compile*). 
It has the following syntax:

```
bibtexmlc [--help] [--destination $DEST] $BSTFILE 
```

- `$DEST` is the name of the output file to write output to. If omitted, output is sent to `STDOUT`. 
- `$BSTFILE` is the (absolute or relative to the working directory) path to the `.bst` file to compile. 

All messages and errors are written to STDERR. 

The executable has the following exit codes:
- `0` if everything worked as normal
- `1` if there was trouble parsing command line options
- `3` if there were problems finding the input file
- `4` if there were problems parsing the file
- `5` if there were problems compiling the file
- `6` if there were was trouble writing the output file 


For example, to compile a .bst file called `plain.bst` to STDOUT:

```
bibtexmlc plain.bst --destination plain.bst.pl
```


### Running the runtime stage

To run some compiled `.bst` code, you can use `./tools/bibtexmlr` ( *r* as in *run*). 
It has the following syntax:

```
bibtexmlr [--help] [--wrap] [--destination $DEST] [--cites $CITES] [--macro $MACRO] $COMPILED_BST $BIBFILE [$BIBFILE ...]
```

- `$DEST` is the name of the output file to write output (think .bbl) to. If omitted, output is sent to `STDOUT`. 
- `$CITES` is a comma-separated set of keys of entries that are assumed to have been cited. Defaults to the special '*' key, which assumes that all entries have been cited. 
- `$MACRO` is a macro to wrap all source references in. If omitted, source references are not shown in the output. 
- `$COMPILED_BST` is the (absolute or relative to the working directory) path to the compiled `.bst` file
- `$BIBFILE` is the name of a bibfile to include. 
- `--wrap` enables emulating BiBTeX's output wrapping. 

All messages and errors are written to STDERR. 

The executable has the following exit codes:
- `0` if everything worked as normal
- `1` if there was trouble parsing command line options
- `2` if the compiled `.bst` file could not be found
- `3` if the compiled `.bst` file was corrupted
- `4` if one of the `.bib` files could not be found
- `5` if there was an error opening the output file
- `6` if something went wrong at runtime

For example, to run the compiled `plain.bst.pl` file from above using a bib file called `data.bib`

```
bibtexmlr plain.bst.pl data.bib
```

### Convenience Scripts

#### makebbl

The [makebbl](./tools/makebbl) script provides a quick and dirty way to intercept the plain
BibTeX output. It's usage is as follows:

```
makebbl [--help] [--destination $DEST] [--cites $CITES] STYLE [$BIBFILE [$BIBFILE ...]]
```

### See also

For documentation on BiBTeX Style Files, the following resources are helpful:

* [Tame the BeaST](http://mirrors.ctan.org/info/bibtex/tamethebeast/ttb_en.pdf) -- in particular sections 3 + 4
* [Designing BIBTEX Styles](http://mirrors.ctan.org/biblio/bibtex/base/btxhak.pdf) -- a.k.a `texdoc btxhak`
* [Names in BibTEX and MlBibTEX](https://www.tug.org/TUGboat/tb27-2/tb87hufflen.pdf) -- for details on how exactly name parsing works
* [The BiBTeX source code](https://github.com/MiKTeX/miktex/blob/master/Programs/Bibliography/bibtex/source/bibtex.web) -- useful for certain implementation details
