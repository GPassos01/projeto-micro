.global _led

_led:
    addi        r9,     r9,  1

    ldb         r10,    (r9)

ret