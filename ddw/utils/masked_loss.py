import torch

from .fourier import apply_fourier_mask_to_tomo


def masked_loss(model_output, target, rot_mw_mask, mw_mask, n2v_mask, mw_weight=2.0, eps=1e-8):
    """
    The self-supervised per-sample loss function for denoising and missing wedge reconstruction.
    The loss is restricted to the voxels manipulated by the N2V/N2V2 blind-spot masking (n2v_mask),
    combined with the missing-wedge frequency weighting (rot_mw_mask, mw_mask, mw_weight).
    """
    residual = target - model_output
    n2v_mask = n2v_mask.float()
    n2v_voxel_count = n2v_mask.sum() + eps

    outside_mw_mask = rot_mw_mask * mw_mask
    outside_mw_residual = apply_fourier_mask_to_tomo(
        tomo=residual, mask=outside_mw_mask, output="real"
    )
    outside_mw_loss = ((outside_mw_residual * n2v_mask) ** 2).sum() / n2v_voxel_count

    inside_mw_mask = rot_mw_mask * (torch.ones_like(mw_mask) - mw_mask)
    inside_mw_residual = apply_fourier_mask_to_tomo(
        tomo=residual, mask=inside_mw_mask, output="real"
    )
    inside_mw_loss = ((inside_mw_residual * n2v_mask) ** 2).sum() / n2v_voxel_count

    loss = outside_mw_loss + mw_weight * inside_mw_loss
    return loss