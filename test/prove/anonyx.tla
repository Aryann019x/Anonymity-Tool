---- MODULE anonyx ----
CONSTANT Packets == {"tor", "clear", "dns", "lo"}
VARIABLES enabled, dropped
Init == enabled = 0 /\ dropped = FALSE
Enable == enabled' = 1 /\ UNCHANGED dropped
Filter(p) == IF enabled = 1 /\ p \in {"clear"}
              THEN dropped' = TRUE
              ELSE UNCHANGED dropped
Next == Enable \/ \E p \in Packets : Filter(p)
Spec == Init /\ [][Next]_<<enabled, dropped>>
THEOREM EnabledImpliesFiltered == Spec => [](enabled = 1 /\ \E p \in {"clear"} : TRUE => <>(dropped))
====
