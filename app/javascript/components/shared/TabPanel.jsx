import { Box } from "@mui/material";

// Content for one tab of a <Tabs> bar. Only the active panel is rendered.
export default function TabPanel({ children, value, index, idPrefix = "tab", ...other }) {
    return (
        <div
            role="tabpanel"
            hidden={value !== index}
            id={`${idPrefix}-tabpanel-${index}`}
            aria-labelledby={`${idPrefix}-tab-${index}`}
            {...other}
        >
            {value === index && <Box sx={{ pt: 3 }}>{children}</Box>}
        </div>
    );
}
