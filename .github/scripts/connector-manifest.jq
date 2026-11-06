# true when a stream connector manifest only holds a single-line summary and description, and
# depends.rpm / depends.deb lists; no value may hold an @TOKEN@ (they are filled by the packaging)
def line: type == "string" and test("^\\S(.*\\S)?$") and (test("@[A-Za-z_]+@") | not);

(keys | sort) == ["depends", "description", "summary"]
and (.summary | line)
and (.description | line)
and (.depends | type == "object" and (keys | sort) == ["deb", "rpm"] and all(.[]; type == "array" and all(.[]; line)))
