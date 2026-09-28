import { TablePagination } from "@mui/material";

// Pager for a list from usePagedList. Hidden when there's nothing to page.
export default function ListPagination({ list }) {
	if (!list.total) return null;

	return (
		<TablePagination
			component="div"
			count={list.total}
			page={list.page - 1}
			rowsPerPage={list.perPage}
			rowsPerPageOptions={[25, 50, 100]}
			onPageChange={(event, newPage) => list.setPage(newPage + 1)}
			onRowsPerPageChange={(event) => list.setPerPage(parseInt(event.target.value, 10))}
		/>
	);
}
