Midterm Project Summary 
=======================

Overall, the class did an excellent job! Many projects demonstrated a strong understanding of typed decisions, 
safe tool execution, and truthful reporting. The strongest submissions supported their implementations with 
thoughtful tests and clear explanations of the system's limitations.

Scores
------

Among the 27 submitted projects, **26 earned at least 95/100**, including **7 full-credit projects**.

+----------+----------+
| Score    | Projects |
+==========+==========+
| 100      |        7 |
+----------+----------+
| 99–99.99 |       11 |
+----------+----------+
| 98–98.99 |        5 |
+----------+----------+
| 95–97.99 |        3 |
+----------+----------+
| 90–94.99 |        1 |
+----------+----------+

*Scores include the recorded late penalties and exclude one non-submission.*


Kudos
------

* Several projects included strong tests for prompt injection, identity substitution, repeated reservations, and false completion 
  claims. A particularly useful example verified that malicious retrieved text reached the model while the action gate still 
  blocked the unsafe reservation.
* Good tests distinguished a successful information lookup from a completed reservation. Some also caught the reverse 
  inconsistency: a blocked response that concealed a reservation that had actually succeeded.
* Strong reports offered interesting observations and accurately explained the implementation and its limitations.

Cautions
---------

* **Make the diagram follow one concrete scenario.** Include the trusted request metadata, actual tool calls and observations, and final response. Show validation before tool dispatch, trace and message updates after every attempted call—including denied calls—and the trace feeding final-response validation. Clear labels and arrows help make this flow understandable.
* **Spell out reservation preconditions.** Saying “perform the required checks” is too vague. Include policy retrieval, project authorization, current qualifications, availability, calibration, maintenance clearance, and after-hours approval when applicable.
* **Keep proposed actions and final claims tied to the evidence.** Preserve the request's resolved fields, including start and end times. A completed response must name a successful state-changing action; other statuses must not claim or hide successful actions.
* **Explain the implementation precisely.** Describe the bounded loop, termination reasons, and major design choices. Gate approval permits execution; it does not guarantee tool success. Likewise, `model_finished` can describe an accepted blocked response, not just a completed reservation. Checking structured fields does not verify every claim in the response text, so be precise about what validation guarantees.
* **Include the benchmark evidence.** Submit the benchmark JSON and a readable results summary so that the reported performance can be checked.