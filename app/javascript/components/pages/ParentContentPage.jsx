import { useState, useEffect } from "react";
import {
    Box,
    Typography,
    Card,
    CardContent,
    Link,
    Chip,
    Alert,
    CircularProgress,
    Stack,
} from "@mui/material";
import OpenInNewIcon from "@mui/icons-material/OpenInNew";
import { portalApi } from "../../utils/api";

export default function ParentContentPage() {
    const [items, setItems] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        portalApi
            .content()
            .then(setItems)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
                <CircularProgress />
            </Box>
        );
    }

    if (error) {
        return <Alert severity="error">{error}</Alert>;
    }

    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                Documents
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
                Handbooks, forms, and resources shared by the school.
            </Typography>

            {items.length === 0 && (
                <Alert severity="info">No documents have been shared yet.</Alert>
            )}

            <Stack spacing={1.5}>
                {items.map((item) => (
                    <Card key={item.id} variant="outlined">
                        <CardContent
                            sx={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 2 }}
                        >
                            <Box>
                                <Link
                                    href={item.url}
                                    target="_blank"
                                    rel="noopener"
                                    sx={{ display: "inline-flex", alignItems: "center", gap: 0.5, fontWeight: 600 }}
                                >
                                    {item.title}
                                    <OpenInNewIcon sx={{ fontSize: 16 }} />
                                </Link>
                                {item.description && (
                                    <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                                        {item.description}
                                    </Typography>
                                )}
                            </Box>
                            {item.category && item.category !== "general" && (
                                <Chip size="small" label={item.category} sx={{ textTransform: "capitalize", flexShrink: 0 }} />
                            )}
                        </CardContent>
                    </Card>
                ))}
            </Stack>
        </Box>
    );
}
