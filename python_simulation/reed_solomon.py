"""Reed-Solomon encode/decode port from HQC reference."""

from __future__ import annotations

from typing import List

from .fft import fft, fft_retrieve_error_poly
from .gf import gf_exp_log, gf_inverse, gf_mul
from .params import VariantParams


def _mod(i: int, modulus: int) -> int:
    return i if i < modulus else i - modulus


def compute_generator_poly(params: VariantParams) -> List[int]:
    gf_exp, gf_log = gf_exp_log()
    poly = [0] * (2 * params.param_delta + 1)
    poly[0] = 1
    tmp_degree = 0
    for i in range(1, 2 * params.param_delta + 1):
        for j in range(tmp_degree, 0, -1):
            poly[j] = gf_exp[_mod(gf_log[poly[j]] + i, params.param_gf_mul_order)] ^ poly[j - 1]
        poly[0] = gf_exp[_mod(gf_log[poly[0]] + i, params.param_gf_mul_order)]
        tmp_degree += 1
        poly[tmp_degree] = 1
    return poly


def reed_solomon_encode(msg: bytes, params: VariantParams) -> bytes:
    if len(msg) != params.param_k:
        raise ValueError("reed_solomon_encode expects PARAM_K bytes")

    gate_value = 0
    tmp = [0] * params.param_g
    poly = list(params.rs_poly_coefs)

    msg_bytes = bytearray(msg)
    cdw_bytes = bytearray(params.param_n1)

    for i in range(params.param_k):
        gate_value = msg_bytes[params.param_k - 1 - i] ^ cdw_bytes[params.param_n1 - params.param_k - 1]

        for j in range(params.param_g):
            tmp[j] = gf_mul(gate_value, poly[j], params)

        for k in range(params.param_n1 - params.param_k - 1, 0, -1):
            cdw_bytes[k] = (cdw_bytes[k - 1] ^ tmp[k]) & 0xFF

        cdw_bytes[0] = tmp[0] & 0xFF

    cdw_bytes[params.param_n1 - params.param_k :] = msg_bytes
    return bytes(cdw_bytes)


def _compute_syndromes(cdw: bytes, params: VariantParams) -> List[int]:
    syndromes = [0] * (2 * params.param_delta)
    alpha = params.alpha_ij_pow
    for i in range(2 * params.param_delta):
        acc = 0
        for j in range(1, params.param_n1):
            acc ^= gf_mul(cdw[j], alpha[i][j - 1], params)
        syndromes[i] = acc ^ cdw[0]
    return syndromes


def _compute_elp(syndromes: List[int], params: VariantParams) -> tuple[List[int], int]:
    delta = params.param_delta
    sigma = [0] * (delta + 1)
    sigma[0] = 1

    deg_sigma = 0
    deg_sigma_p = 0
    pp = -1
    d_p = 1
    d = syndromes[0]
    x_sigma_p = [0] * (delta + 1)
    x_sigma_p[1] = 1

    for mu in range(2 * delta):
        sigma_copy = sigma[:]
        deg_sigma_copy = deg_sigma

        dd = gf_mul(d, gf_inverse(d_p, params), params)

        lim = min(mu + 1, delta)
        for i in range(1, lim + 1):
            sigma[i] ^= gf_mul(dd, x_sigma_p[i], params)

        deg_x = (mu + 1) if pp == -1 else (mu - pp)
        deg_x_sigma_p = deg_x + deg_sigma_p

        do_update = (d != 0) and (deg_x_sigma_p > deg_sigma)
        if do_update:
            deg_sigma = deg_x_sigma_p

        if mu == 2 * delta - 1:
            break

        old_x = x_sigma_p[:]
        if do_update:
            pp = mu
            d_p = d
            for i in range(delta, 0, -1):
                x_sigma_p[i] = sigma_copy[i - 1]
            deg_sigma_p = deg_sigma_copy
        else:
            for i in range(delta, 0, -1):
                x_sigma_p[i] = old_x[i - 1]

        d = syndromes[mu + 1]
        for i in range(1, lim + 1):
            d ^= gf_mul(sigma[i], syndromes[mu + 1 - i], params)

    sigma_fft = [0] * (1 << params.param_fft)
    sigma_fft[: delta + 1] = sigma
    return sigma_fft, deg_sigma


def _compute_roots(sigma_fft: List[int], params: VariantParams) -> List[int]:
    w = fft(sigma_fft, params.param_delta + 1, params)
    return fft_retrieve_error_poly(w, params)


def _compute_z_poly(sigma_fft: List[int], degree: int, syndromes: List[int], params: VariantParams) -> List[int]:
    z = [0] * params.param_n1
    z[0] = 1

    for i in range(1, params.param_delta + 1):
        if i <= degree:
            z[i] = sigma_fft[i]

    z[1] ^= syndromes[0]

    for i in range(2, params.param_delta + 1):
        if i <= degree:
            z[i] ^= syndromes[i - 1]
            for j in range(1, i):
                z[i] ^= gf_mul(sigma_fft[j], syndromes[i - j - 1], params)

    return z


def _compute_error_values(z: List[int], error: List[int], params: VariantParams) -> List[int]:
    gf_exp, _ = gf_exp_log()
    delta = params.param_delta

    beta_j = [0] * delta
    e_j = [0] * delta

    delta_counter = 0
    for i in range(params.param_n1):
        found = 0
        if error[i] != 0:
            for j in range(delta):
                if j == delta_counter:
                    beta_j[j] = (beta_j[j] + gf_exp[i]) & 0xFFFF
                    found += 1
        delta_counter += found
    delta_real_value = delta_counter

    for i in range(delta):
        tmp1 = 1
        tmp2 = 1
        inverse = gf_inverse(beta_j[i], params)
        inverse_power = 1

        for j in range(1, delta + 1):
            inverse_power = gf_mul(inverse_power, inverse, params)
            tmp1 ^= gf_mul(inverse_power, z[j], params)

        for k in range(1, delta):
            tmp2 = gf_mul(tmp2, (1 ^ gf_mul(inverse, beta_j[(i + k) % delta], params)), params)

        if i < delta_real_value:
            e_j[i] = gf_mul(tmp1, gf_inverse(tmp2, params), params)
        else:
            e_j[i] = 0

    error_values = [0] * params.param_n1
    delta_counter = 0
    for i in range(params.param_n1):
        found = 0
        if error[i] != 0:
            for j in range(delta):
                if j == delta_counter:
                    error_values[i] = (error_values[i] + e_j[j]) & 0xFFFF
                    found += 1
        delta_counter += found

    return error_values


def reed_solomon_decode(cdw: bytes, params: VariantParams) -> bytes:
    if len(cdw) != params.param_n1:
        raise ValueError("reed_solomon_decode expects PARAM_N1 bytes")

    cdw_bytes = bytearray(cdw)
    syndromes = _compute_syndromes(cdw_bytes, params)
    sigma_fft, deg = _compute_elp(syndromes, params)
    error = _compute_roots(sigma_fft, params)
    z = _compute_z_poly(sigma_fft, deg, syndromes, params)
    error_values = _compute_error_values(z, error, params)

    for i in range(params.param_n1):
        cdw_bytes[i] = (cdw_bytes[i] ^ error_values[i]) & 0xFF

    start = params.param_g - 1
    return bytes(cdw_bytes[start : start + params.param_k])
