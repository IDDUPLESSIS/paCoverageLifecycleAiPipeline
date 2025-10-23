# Architecture

```
Assets (CSV/SQL) --> aicm.RAI_SP0 --> Views (v_*) --> Procs (sp_*) --> aicm.PayloadCache (JSON)
                                                            |
                                                            v
                                                   Power Automate (HTML email)
```
