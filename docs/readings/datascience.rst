Data Processing for Machine Learning 
====================================

This supplemental reading introduces basic data science concepts for machine learning 
and provides hands-on examples that leverage the Python programming ecosystem, 
including ``pandas``, ``numpy`` and ``maplotlib`` libraries. 

By the end of this reading students should be able to: 

1. Distinguish rows, features, targets, and identifiers.
2. Inspect numeric and categorical variables
3. Use ``pandas``, ``numpy``, and ``matplotlib`` for basic data analysis. 
4. Explain how to treat categorical variables 
5. Identify missing values and implement some basic methods for treating them. 
6. Distinguish regression from classification 
7. Choose a reasonable loss function for a basic prediction problem. 
8. Explain the purpose of training, validation and test data. 

In order to illustrate the concepts in what follows, we will make use of a synthetic materials dataset, and 
we will manipulate it using Python code. We recommend that you follow along using VSCode running against 
your student VM where all necessary libraries are preinstalled. 

The dataset we will use describes manufactured materials ("polymers") from a fictional industrial engineering lab. 
Each observation (row) corresponds to a single specimen that was produced using their machine. Three different
grades of materials (corresponding to three different polymer formulas) can be produced. 
As the specimens are being produced, sensors in the lab record the average temperature, pressure and "feed rate", 
that is, the rate that the raw material is fed into the machine. After the specimens are produced, 
they go through a testing and quality assurance process where first their tensile strength is measured 
and finally, the QA test determines if the specimen is defective. The dataset is available from the 
class website `here <https://raw.githubusercontent.com/joestubbs/coe-379l-fa26/refs/heads/main/data/unit01/polymer_samples.csv>`_. 


Datasets and DataFrames
-----------------------
Machine Learning typically begins with raw data or *observations* about a process or phenomenon. There 
are many different forms that such raw data can take. In a tabular dataset, each row normally 
represents a single observation, and each column records one property of that observation. 

For example, in the polymer dataset, one observation is one manufacturing run and the 
specimen produced by that run. The temperature, pressure, and feed rate are average measured 
process conditions. The material grade identifies the polymer formulation. Tensile strength and 
the defect label are outcomes measured after manufacturing.

We'll use the ``pandas`` library to read the raw CSV file into a dataframe object. A dataframe is a 
like a 2d-array that can hold heterogeneous data. Each data frame contains rows and columns, like a 
spreadsheet or database table. 


.. code-block:: python 

    import pandas as pd

    # create a dataframe directly from the raw csv
    url = "https://raw.githubusercontent.com/joestubbs/coe-379l-fa26/refs/heads/main/data/unit01/polymer_samples.csv"
    df = pd.read_csv(url)

    type(df)
    --> pandas.DataFrame


The dataframe API has a variety of useful methods for accessing and manipulating the data it contains. 
We'll use the ``info()`` to get a high-level description of the dataframe, and the ``head()`` method 
to inspect the first several rows. 

.. code-block:: python 

    df.info()


You should see an output similar to the following:

.. code-block:: console 

    <class 'pandas.DataFrame'>
    RangeIndex: 30 entries, 0 to 29
    Data columns (total 7 columns):
    #   Column                Non-Null Count  Dtype  
    ---  ------                --------------  -----  
    0   sample_id             30 non-null     str    
    1   material_grade        30 non-null     str    
    2   temperature_c         30 non-null     int64  
    3   pressure_mpa          30 non-null     float64
    4   feed_rate_mm_s        30 non-null     int64  
    5   tensile_strength_mpa  30 non-null     float64
    6   defective             30 non-null     bool   
    dtypes: bool(1), float64(2), int64(2), str(2)
    memory usage: 1.6 KB



Features, Targets, and Identifiers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
A *feature* is a value supplied to the model as an input. A *target* is the value we want the model to 
predict. An *identifier* distinguishes a specific observation but usually does not describe the 
process that generated its outcome. We learned in class that if the target is a continuous variable, 
then the problem is a regression problem, while if the target is a discrete variable (i.e., takes 
only finitely many values), then the problem is a *classification* problem. 

A single dataset can support multiple prediction problems. For example, with the materials dataset, 
we could choose to predict *tensile_strength_mpa*, a continuous variable, and thus a regression 
problem, or we could choose to predict *defective*, a discrete variable with just two possible values 
(True and False), and thus a classification problem. 

.. note:: 

    A column's role depends on the question. Tensile strength is a target in the regression 
    problem, but it could also be an input (feature) in a different problem (e.g., when predicting 
    defective). Whether that would be legitimate depends on when the value becomes available 
    and what decision the system is intended to support.


Inspecting the Data 
-------------------

Before fitting a model, it is always best to inspect the dataset. The pandas DataFrame API provides 
operations that answer different questions, for example: 

* ``df.shape`` --  How many rows and columns?
* ``df.dtypes`` --  What type was assigned to each column?
* ``df.describe()`` --  What are the numerical ranges and summary statistics?
* ``df.isna().sum()``  How many values are missing in each column?

These operations help you understand the quality of the data and diagnose certain kinds 
of issues. In the real world, datasets can contain any number of issues, including missing data, 
data with the wrong type, or data that cannot be "correct". And here, "correct" is relative 
to the context at hand. 

Consider a column containing temperature values like the *temperature_c* column. We know temperature 
in general should be a numeric value, so if the column contains the string "abc", we know it is not valid. 
But usually we can say more depending on the context. For polymers like the ones manufactured in the lab, valid 
temperature values could be between 180C and 250C, but those would not be valid values for the average 
daily Austin temperature (at least, I hope not!)

Pandas and Numpy 
^^^^^^^^^^^^^^^^
In general, we use ``pandas`` and ``numpy`` for different tasks in ML. 
Typically, we use ``numpy`` to work with numerical arrays and vectors. It is very fast and efficient, because 
We use ``pandas`` to work with entire spreadsheets, database tables or other data. It is especially convenient 
when columns have possibly different data types. 
ML libraries often accept either pandas DataFrames or numpy arrays and may convert between them internally.

Once we have read an entire dataset into a dataframe, we can select individual columns by name using 
a dictionary-like access syntax, e.g., ``df["temperature_c"]`` returns just the temperature columns. 
The object type returned is technically a pandas ``Series``. 
We can also select multiple columns using a double-bracket (i.e., ``[[ -- ]]``) syntax. In that case, 
a full DataFrame object is returned. 
We can then perform vectorized operations 
on the entire column without looping --- this is by far the most efficient way to work with the data. 

.. code-block:: python 

    temperatures = df["temperature_c"]         # Pandas Series
    x = df[["temperature_c", "pressure_mpa"]]  # Pandas DataFrame
    x_array = x.to_numpy()                     # Numpy array

    prediction = 0.15 * df["temperature_c"] + 10.0
    per_example_loss = (df["tensile_strength_mpa"] - prediction) ** 2


.. note:: 

    If you find yourself writing a ``for`` loop in Python to iterate over a Pandas object 
    stop and ask if there is another way to implement the code! The loop can be very 
    inefficient. 

Visualizing Relationships 
-------------------------

Categorical Variables 
----------------------

Predictions and Loss 
---------------------
* Regression -- Continuous values --  MSE or MAE
* Binary Classification -- Probability of positive class -- Binary cross-entropy
* Multiclass classification -- Probability distribution over classes -- Sparse categorical cross-entropy

Training and Validation 
------------------------


Exercises: Test Your Understanding 
----------------------------------