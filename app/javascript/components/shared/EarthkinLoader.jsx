import { Box, Typography, keyframes } from "@mui/material";

// Gentle "breathing" pulse for the Earthkin mark while content loads.
const breathe = keyframes`
    0%   { opacity: 0.4; transform: scale(0.92); }
    50%  { opacity: 1;   transform: scale(1); }
    100% { opacity: 0.4; transform: scale(0.92); }
`;

// Shared loading indicator: a pulsing Earthkin logo. Use this for content /
// page / section loading instead of ad-hoc "Loading..." text or a bare
// CircularProgress, so every loading state looks the same and on-brand.
//
// Props:
//   size   — logo width in px (default 160)
//   label  — text under the logo (default "Loading…"; pass "" to hide)
//   minHeight — vertical space to reserve so the page doesn't jump (default 240)
export default function EarthkinLoader({ size = 160, label = "Loading…", minHeight = 240, sx }) {
    return (
        <Box
            role="status"
            aria-live="polite"
            aria-busy="true"
            sx={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 2,
                width: "100%",
                minHeight,
                ...sx,
            }}
        >
            <Box
                component="img"
                src="/logo-green.png"
                alt=""
                sx={{
                    width: size,
                    maxWidth: "70%",
                    height: "auto",
                    animation: `${breathe} 1.6s ease-in-out infinite`,
                    // Respect users who prefer reduced motion.
                    "@media (prefers-reduced-motion: reduce)": {
                        animation: "none",
                        opacity: 0.85,
                    },
                }}
            />
            {label ? (
                <Typography variant="body2" color="text.secondary">
                    {label}
                </Typography>
            ) : null}
        </Box>
    );
}
