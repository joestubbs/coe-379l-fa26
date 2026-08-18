# COE 379L Fall 2026 Lecture Materials

Course materials for the Fall 2026 instance of COE 379L: Software Design for Responsible Intelligent Systems, 
UT Austin.

## Building Locally

We are using Nix for the local build. Note that the requirements.txt file is included only for the ReadTheDocs build.

To run the doc engine locally, first enter the Nix development environment

```
$ nix develop -i 
```

We recommend the `-i` so that environment variables set in the outside shell don't interfere. 
In particular, this can prevent issues with locale errors, etc.

Once the Nix development environment is activated, use the Makefile targets to launch the documentation site, 
e.g., 

```
$ make livehtml
. . . 
The HTML pages are in _build/html.
[sphinx-autobuild] Serving on http://127.0.0.1:7898
```

