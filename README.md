This is a basic approach for cleaning and de-duplicating company names. By no means a final and optimal approach, but it is a starting point for this kind of text data problem. In this example, variations of 'Amazon' are provided with their total level of spend as the input data. One record of 'UK Medical Supplies' is included to indicate what happens when a company is not matched to any others.

**High-level process**
1. Initial text processing e.g. make names lowercase, remove additional whitespace, remove specified stop words.
2. Fuzzy matching the names on themselves to identify possible matches.
3. Checking whether these matches are phonetically similar to increase the confidence of a correct match.
4. For each match that meets the benchmark, return the original name that has the largest level of spend.
5. Export the results to Excel for manual review (if needed).

Running this code on the example data cleans the original 15 names to six names. These could be cleaned further, for example by adding additional stop words.
