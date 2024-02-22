A basic approach for cleaning messy company name data. By no means a final and optimal approach, but a starting point for this kind of text data problem. In this example, variations of 'Amazon' are provided with their total level of spend as the input data.

**High-level process**
1. Initial text processing e.g. make names lowercase, remove additional whitespace, remove specified stop words.
2. Fuzzy matches the names on themselves to identify possible matches.
3. Checking whether these matches are phonetically similar increase the confidence of a correct match.
4. For each match that meets the benchmark, return the original name that has the largest level of spend.
5. Export the results to Excel for manual review (if needed).

Running this code on the example data cleans the original 12 variations of 'Amazon' to five names. These could then be cleaned further, for example by adding additional stop words. It will never clean the text completely but is an improvement.
