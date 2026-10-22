Propositions as Types and A First Look at Lean 
===============================================

In the previous lecture, we have seen how we can define desirable properties 
of a software system using precise formal mathematics using precise definitions of 
state spaces, predicates, executions, safety properties, liveness properties, and assumptions. 
We can now state claims such as:

.. math::

   \forall \pi,\alpha,k,\quad
   \operatorname{ValidExecution}(\pi,\alpha)
   \Longrightarrow
   \neg\operatorname{IdentitySubstitution}(\pi(k),\alpha(k)).

Stating the property precisely is an essential step.

In this module, we turn to the issue of actually proving those properties to be true. Our 
approach will be to use a programming language (Lean) that allows us to 
construct both propositional statements as well as their proofs with the 
type system of the language. So, the first central question, which we tackle 
today is this: 

  *How can a logical proposition become a type, and how can a proof 
  become an object that Lean checks?* 

By the end of this lecture, students should be able to: 

* read a basic typing declaration, :math:`t:T`
* distinguish :math:`\operatorname{Prop}` from ``Bool``
* explain the Curry–Howard correspondence at an introductory level
* interpret implication as a function type
* interpret conjunction and disjunction as constructions requiring evidence
* read simple Lean theorem declarations
* understand the difference between term proofs and tactic proofs to construct proofs
* connect a safety property proof obligation with a Lean theorem statement.


Types, terms, and type checking
-------------------------------

The concept that will all us express formal mathematical statements and their proofs in a programming 
language is that of a *type*. 
You have already encountered types in everyday programming in languages such as Python. 
Examples of values and their types include:

.. code-block:: text

    3       : Nat
    "joe" : String
    true    : Bool

The notation:

.. math::

   t:T

is read:

    "Term :math:`t` has type :math:`T`.”

A type describes what kind of value a term represents and which operations are valid for it.

Functions also have types. A function that accepts an integer and returns an integer has
type:

.. math::

   Int\to Int

For example, in Python we might right: 

.. code-block:: Python 

  def inc(n: int) -> int:
      return n + 1 

This function accepts a single integer and returns its value plus one, another integer. 

Lean 
^^^^
Lean is a strict, pure functional programming language supporting what are called 
dependent types. We'll define this more precisely later, but for now just understand that the 
dependent types available in Lean are powerful enough to express complex mathematical expressions, 
including the predicates and theorems about software properties we have been developing. 

But we can express simple terms and types in Lean as well. 
For example, in Lean, as we will see later, the same integer function above would be defined like so: 

.. code-block:: lean

    def inc (n : Int) : Int := n + 1

You can see that the syntax is remarkably similar to the Python counterpart: 

* The keyword ``def`` is used to indicate we are defining a new function, just like in Python 
* We give the function the name ``inc`` 
* The syntax ``(n: Int)`` declares that the function takes a single integer argument 
* The syntax ``: Int`` declares that the function's return type is ``Int``. 
* Finally, ``:= n + 1`` defines the function's return value as 1 plus the argument. 

In both Python and in Lean, the checking the type of the function amounts to verifying that the
body produces an integer whenever the function is given an integer input.

Different Kinds of Type Checking
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In this course, we have encountered two primary mechanisms involving types:

Python type annotations
    Annotations communicate intended types and support external analysis, but ordinary Python does
    not generally enforce them at runtime.

Pydantic models
    Pydantic validates runtime data against a schema and constructs typed Python objects.

Lean goes much further. Lean's type checker statically verifies that every term has its 
declared type at compile time, guaranteeing type correctness before the code is ever executed.

Note that this is non-trivial, even for "normal" programming types. Lean's type checker must 
construct a "proof" that all terms have the correct type, regardless of events that happen at 
runtime. 

Moreover, a key new idea in Lean is that some Lean types represent logical propositions. Checking a term 
against such a type is equivalent to checking a proof.

The ``Prop`` and ``Bool`` Types 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Lean distinguishes propositions from executable Boolean values. Consider a Lean function 
with signature: 

.. code-block:: lean

    def check (s: State) : Bool

where we are omitting the ``State`` type for now.  
For a state ``s``, ``check s`` computes either ``true`` or ``false``.

Lean introduces a special type: ``Prop``, short for Proposition.
A proposition is a mathematical statement or assertion that can, in principle, be true or false.
For instance: 

* :math:`2 + 2 = 4`
* :math:`5 < 3`
* :math:`\forall n \in Nat, n + 0 = n`

are all examples of propositions. 
In Lean, these statements are not merely boolean expressions evaluated at runtime. 
Instead, **they are types themselves**.

But wait, did we say the expression :math:`2 + 2 = 4` is a *type*? Yes, that is correct, 
it is a type, not a term. This is a key distinction that must be kept firmly in mind, 
as it doesn't have a proper analog in the "normal" programming languages you have likely 
encountered, such as Python. 

In Lean, the type ``Prop`` is what is referred to as a *type universe*, and the elements 
``P`` of ``Prop`` are **themselves types**!

If :math:`2 + 2 = 4` is a type, then what are the terms with that type? The terms are 
exactly **the proofs**. More on this point soon. 

But then, what exactly is the difference between :math:`\operatorname{Prop}` and ``Bool``? 

* ``Bool`` is computational -- An expression of type ``Bool`` is a piece of code that can 
  be executed to yield true or false. For example, ``4 < 5`` evaluates to true. ``Bool`` 
  can only represent assertions that can be computed. 
* :math:`\operatorname{Prop}` is mathematical -- A :math:`\operatorname{Prop}` represents 
  a logical assertion regardless of whether a computer program can calculate its truth 
  value. For example, consider the famous Golbach conjecture: *Every integer greater than 2 
  is the sum of two primes.* No one knows if this statement is true of false, and no computer 
  algorithm can decide it, and yet, it can be easily stated as a :math:`\operatorname{Prop}`. 


Thus, returning to the first function we defined above, consider the following variant 
defined like so: 

.. code-block:: lean 

    def checkp (s: State) : Prop 


In this case, ``checkp s`` is returning a :math:`\operatorname{Prop}` for an input state ``s``, 
and thus, deciding the truthfulness of ``checkp s`` requires a proof -- it cannot be computed like 
a ``Bool`` type. 

The Curry-Howard correspondence
-------------------------------

This leads directly to one of the most remarkable discoveries in computer science and mathematical 
logic: the Curry-Howard Correspondence (also known as the Propositions-as-Types and 
Proofs-as-Programs paradigm).

The Curry--Howard correspondence relates logic and type theory by connecting mathematical 
propositions and proofs to types and terms. It goes beyond showing that there is a bijection between 
the two kinds of objects. Under the correspondence, the mapping preserves proofs and programs, 
simplification and evaluation. 

Specifically, under the correspondence, objects from logic are mapped to objects from 
types in the following way: 

.. list-table::
   :header-rows: 1
   :widths: 42 58

   * - Logic
     - Types
   * - Proposition :math:`P`
     - A type representing :math:`P`
   * - Proof of :math:`P`
     - A term whose type is :math:`P`
   * - Implication :math:`P\to Q`
     - A function from :math:`P` to :math:`Q`
   * - Conjunction :math:`P\land Q`
     - A product type (i.e., tuple) made from :math:`P` and :math:`Q`
   * - Disjunction :math:`P\lor Q`
     - A sum type (i.e., union) made from :math:`P` and :math:`Q`
   * - True proposition
     - A type that is inhabited by a term 
   * - False proposition
     - A type with no inhabitants 
..    * - Universal statement :math:`\forall x:T,\ P(x)`
..      - A function producing evidence of :math:`P(x)` for arbitrary :math:`x`
..    * - Existential statement :math:`\exists x:T,\ P(x)`
..      - A witness :math:`x` together with evidence of :math:`P(x)`

Why should this correspondence be true? The fundamental underlying intuition is that 
both logic and programming are built on the exact same underlying mechanics: 
construction, evidence and transformations. 

For example, let us suppose we implement a type (or a class, etc.) that holds the data 
associated with whether a proof of a proposition exists. Call that ``Prop``.  

Now, suppose we have two propositions, ``P`` and ``Q`` (that is, they are elements of ``Prop``).
If we think about the implication, :math:`P \implies Q`, that says "if we have a proof of P, then 
we can construct a proof of Q". How would we go about constructing a proof of Q from a proof 
of P? 

If we remember that the data associated with ``P`` and ``Q`` were the proofs, then we merely 
need a function :math:`f: P \to Q`. This would do exactly what we wanted: given a proof ``p`` of ``P``
it would construct a proof of ``Q`` as ``f(p)`` would be an element of ``Q``. 

One can proceed in a similar way with the other constructions. For example, let us consider 
:math:`P \land Q`. What does it mean to have a proof of :math:`P \land Q`? It means to have a 
proof of :math:`P` and a proof of `:math:`Q`. In other words, given proofs :math:`p\in P`
and :math:`q\in Q`, the tuple ``(p, q)`` is exactly a proof of :math:`P\land Q`. 


A First Look at Lean: Propositions and proofs
----------------------------------------------

Let us look at some concrete examples in Lean to see these in action. You don't need to 
fret over the specific syntax at this time. Just try to absorb the big picture. 

Types, Terms and Functions 
^^^^^^^^^^^^^^^^^^^^^^^^^^

You have actually already seen an example of a function defined in Lean that included a 
parameter with a declared type:

.. code-block:: lean

    def inc (n : Int) : Int := n + 1

In the code above, ``inc`` is the function name, ``n`` is a parameter of type ``Int``, and 
the return type of the function is also ``Int``. The ``n+1`` is a term, and the Lean type 
checker verifies that ``n+1`` has type ``Int`` whenever ``n`` has type ``Int``. 


Theorems and Implication as a Function Type
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Lean provides the keyword ``theorem`` for declaring propositions that you intend to prove. 
The syntax looks like this: 

.. code-block:: lean 

    theorem my_theorem (P : Prop) : P → P := ... 

Here we are declaring a new theorem called ``my_theorem``. It takes as a single parameter 
a ``Prop``, ``P``, and its return type is ``P → P``. Now, this may seem a little odd, but 
keep in mind that elements of ``Prop`` are types, and thus, ``P → P`` is also a type! It is the 
type associated with the proposition :math:`P\implies P`, which is, of course, a triviality.
But we still need to provide a proof to make the Lean type checker happy. 

How do we provide a proof of this theorem? Recall from the Curry-Howard correspondence that 
implications correspond to functions. Thus, in order to satisfy the type constraint, we need to construct
a function from ``P → P``. What function should we define? 

Conceptually, we need to define a function that takes a proof of ``P`` to a proof of ``P``. The identity function 
will work just fine! 

In Lean, we can define anonymous functions using the keyword ``fun`` like so: 

.. code-block:: lean 

    fun h => h

The code above defined the anonymous identity function on one parameter, ``h``. The syntax 
``h => h`` says "for input ``h`` return ``h``". Thus, putting it all together, we can give a proof 
of ``my_theorem`` as follows: 

.. code-block:: lean 

    theorem my_theorem (P : Prop) : P → P :=
        fun h => h

We are defining the return of ``my_theorem`` to be the identity function ``fun h => h`` which, conceptually, 
maps a proof of ``P`` to itself. 

Another Example: Conjunction (:math:`\land`)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Let us consider a second theorem involving conjunction: 

.. code-block:: lean 

    theorem another (P Q: Prop) : P ∧ Q → Q ∧ P := ... 

This theorem says that if ``P`` and ``Q`` are propositions, then ``P ∧ Q`` implies ``Q ∧ P``. Again, 
this is probably obvious to you, but in Lean, we have to provide a proof. 

Once again, the proposition :math:`P ∧ Q \implies Q ∧ P` is a type in Lean. To construct a proof 
we need to provide a term of that type. As an implication, by Curry-Howard again we need to define 
a function from ``P ∧ Q → Q ∧ P``. But again by Curry-Howard, an element of type ``P ∧ Q`` 
(or ``Q ∧ P``) is a tuple/product type. So, we need to define a function that takes a tuple ``(p, q)``
where ``p`` is a proof of ``P`` and ``q`` is a proof of ``Q`` to a tuple of type ``Q x P``. 
But that is easy! Just map ``(p, q)`` to the tuple ``(q, p)``. 

In Lean, the syntax for that is: 

.. code-block:: lean 

    theorem another (P Q: Prop) : P ∧ Q → Q ∧ P :=
        fun h => ⟨h.right, h.left⟩

where ``h`` here represents the element ``P ∧ Q``, ``h.right`` represents ``Q`` and ``h.left``
represents ``P``. But don't worry too much about the details of the syntax at this time. 


An Example with Disjunction (:math:`\lor`)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Consider the following example involving disjunction: 

.. code-block:: lean 

    theorem third (P Q: Prop) : P → P ∨ Q := ... 

Once again, to prove this theorem we must provide a term of type ``P → P ∨ Q``. By the Curry-Howard 
correspondence, that implication corresponds to a function from ``P`` to ``P ∨ Q``. To define such 
a function, it is enough to define how to map an individual ``p`` in ``P``. But a ``p`` of type 
``P`` is just a proof of ``P``, and an element of type ``P ∨ Q`` is just a sum type (or union type), 
that is, it is a proof of ``P`` *or a proof* of ``Q``. So, we can choose to map ``p`` to itself, 
thought of as a union type. 

.. code-block:: lean 

    theorem third (P Q: Prop) : P → P ∨ Q :=
        fun h => Or.inl h

We're using a funny constructor, the ``Or.inl`` which essentially turns a proof of ``P`` into a 
proof of ``P ∨ Q``. In fact, this is the type signature of ``Or.inl``: 


.. code-block:: lean 

    Or.inl {a b : Prop} (h : a) : a ∨ b

But again, don't worry about understanding the details of the syntax at this time.     

A Quick Introduction to Tactics 
--------------------------------
Defining these functions explicitly by hand to prove a theorem is called a *term proof* because 
one exhibits a term inhabiting the type of the proposition directly. It is fine for these small 
cases but it quickly becomes very difficult for most people. 

Lean offers another method for developing proofs called *tactics*. 
Tactics are interactive commands that automate and simplify the process of developing a proof. Instead 
of giving the entire final term proof all at once, a tactic is a set of instructions that  
allows you to guide Lean to building the term for you. 

Proof States and Goals 
^^^^^^^^^^^^^^^^^^^^^^
The key idea with tactics is that Lean provides you with a *proof state*. You enter what is called 
*tactic mode* using the ``by`` keyword after a theorem statement. 

A proof state consists of two primary components: 

* Local Context / Hypotheses: The variables and assumptions currently available to you. 
  These are depicted above the ⊢ turnstile in the Lean Infoview.
* Goal: The statement you are currently trying to prove. This is presented below the ⊢ turnstile.

Each tactic you execute, if successful, modifies the proof state by adding or modifying hypotheses, 
breaking down complex goals, or solving goals completely. 

Let us illustrate with an initial example. We'll use our example from earlier, but this time 
we'll give a tactic proof. 

We start by entering the same code, but we add the ``by`` at the end to indicate we want to enter 
tactic mode. 

.. code-block:: lean 

    theorem my_theorem (P : Prop) : P → P := by 

At this point, the Infoview shows us the following 

.. code-block:: lean 

    1 goal
    P : Prop
    ⊢ P → P

The ``P: Prop`` is our hypothesis, while the ``⊢ P → P`` is our goal. In other words, we get to 
assume that ``P`` is a ``Prop`` and our goal is to prove ``P → P``. 

The first tactic we can use is called the ``intro`` tactic. It introduces a hypothesis to the 
proof state. We use it with the syntax ``into <h>`` where ``<h>`` is the name we want to give to 
the introduced hypothesis. 

We can use ``intro hp``  to introduce a new hypothesis, ``hp``:

.. code-block:: lean 

    theorem my_theorem (P : Prop) : P → P := by 
        intro hp 

At this point the Infoview shows: 

.. code-block:: lean 

    1 goal
    P : Prop
    hp : P
    ⊢ P

We have added the hypothesis ``hp: P`` to our proof state and the goal has become ``P``. 
That is perfect because it matches our hypothesis exactly. 

We can now finish the proof using a second tactic, the ``exact`` tactic. The syntax is 
``exact <h>`` where ``<h>`` is some hypothesis that exactly matches a goal. Thus, we can use 
``exact hp`` to close the goal and complete the proof: 

.. code-block:: lean 

    theorem my_theorem (P : Prop) : P → P := by 
        intro hp 
        exact hp 

The Messages section of the Infoview shows: 

.. code-block:: lean 

    Goals accomplished!



States, Transitions, and a Safety Property 
------------------------------------------

Let us illustrate one slightly more involved example related to actual software 
systems. We will consider the states associated with a tool call. For simplicity 
we will assume that the states a tool call can go through are as follows:

* Proposed -- The LLM has proposed a tool call with specific parameters. 
* Rejected -- The application has rejected the specific tool call, and the LLM must start over with a new 
  proposal. 
* Validated -- The application has determined that a specific tool call should be allowed. 
* Executed -- The application has executed a valid tool call. 

We can model these four possible tool call states in Lean with what is called an *inductive type*. 
Inductive types are the primary way of introducing new types in Lean. An ``inductive`` declaration introduces
a new type by specifying its *constructors*. Constructors are the permitted ways to build
values of the new type.

For our valid tool call states, conceptually we want to use something like an enumeration. In Lean, we can proceed as follows: 

.. code-block:: lean 

    inductive ToolCallState where
    | proposed
    | validated
    | rejected
    | executed

Again, you do not need to worry too much about the syntax at this type. 

For now, just understand that the inductive type above defines a simple sum type (i.e., what we have referred to 
as an enumeration in Python). The contructos appear after the ``|``, and in this case, they take no arguments and just directly 
produce a value of type ``ToolCallState``. So, ``proposed``, 
``validated``, ``rejected``, and ``executed`` are the possible values. These can be references using a dot notation. 
For example, 

.. code-block:: lean

    ToolCallState.proposed : ToolCallState

    ToolCallState.executed : ToolCallState


Next we want to define the allowable transitions. We can think of transitions as corresponding 
to actions (usually described with a verb) that our application will take and as transitioning a 
tool call from one state to another. What actions can our application takes? We'll define just a 
subset, for simplicity:

* approve --- The application can approve a proposed tool call. This action moves the tool call from 
  proposed to validated. 
* deny ---  The application can deny a proposed tool call. This action moves the tool call from 
  proposed to rejected.  
* dispatch --- The application can dispatch an approved tool call. This action moves the tool call from 
  validated to executed.

Next we would like to define the valid transitions as a new type in Lean. How do we do this? 

We can use ``inductive`` again, but this time it is more interesting because it does not simply enumerate transition values. 
Instead, it defines a proposition indexed by the source and destination states. 
That is, it takes two ``ToolCallState`` values --- the source state and destination state --- and produces a
proposition:

.. code-block:: lean 

    inductive ValidTransition :
        ToolCallState → ToolCallState → Prop where
    | approve :
        ValidTransition
            ToolCallState.proposed
            ToolCallState.validated
    | deny :
        ValidTransition
            ToolCallState.proposed
            ToolCallState.rejected
    | dispatch :
        ValidTransition
            ToolCallState.validated
            ToolCallState.executed    

This proposition means:

    “A one-step transition from ``source`` to ``destination`` is allowed.”

Each of the three constructors provide evidence (i.e., a proof term) for exactly one of the allowed transitions.
For example, the constructor

.. code-block:: lean

    ValidTransition.approve

has type

.. code-block:: lean

    ValidTransition
      ToolCallState.proposed
      ToolCallState.validated

Thus, ``ValidTransition.approve`` is evidence that a transition from ``proposed``
to ``validated`` is allowed.

Similarly:

.. code-block:: lean

    ValidTransition.deny

is evidence that ``proposed → rejected`` is allowed, and

.. code-block:: lean

    ValidTransition.dispatch

is evidence that ``validated → executed`` is allowed.

No constructor produces evidence of

.. code-block:: lean

    ValidTransition
      ToolCallState.proposed
      ToolCallState.executed

so the model does not permit a direct transition from ``proposed`` to ``executed``.

How does this relate to Curry-Howard? The key point is that valid transition is represented by evidence (i.e., a proof term) 
inhabiting the corresponding ValidTransition proposition.


We can now state a safety property that we would like to prove, namely, that it is not possible to transition directly 
from proposed to executed --- in order to transition to executed we must first transition to validated. 

We can state it as follows: 

.. code-block:: lean 

    theorem no_direct_propose_execute :
    ¬ ValidTransition
      ToolCallState.proposed
      ToolCallState.executed := by ... 

In English, this says that there is not a valid transition from proposed to executed. We can prove it using a tactic 
proof like so: 

.. code-block:: lean 

    theorem no_direct_propose_execute :
    ¬ ValidTransition
      ToolCallState.proposed
      ToolCallState.executed := by
      intro h
      cases h

When the parameter ``h`` is an inductive type, the ``cases h`` tactic splits the main goal across each of the constructors 
of the inductive type. You will see more on tactics in the coming lectures. 


