ExploreFNIRS is a tool which allows the user to move through designed 
experiments to explore the results of processing on Grand Average plots 
across groups and trials

Requires that the following properties are filled in in the fNIR.info struct
    *SubjectID
    *Group
    *Session
    *Trial
    *Block
    *Condition

All fNIRS segments should be loaded as a Cell structure into the opening argument
    or if no opening argument is provided, the global ExploreFNIRS.data can be loaded
Data is expected as a {N,1} cell where each cell is an individual segment