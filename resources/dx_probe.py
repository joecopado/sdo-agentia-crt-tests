"""Probe helper, not part of the login: describes what a Copado CI/CD Test record's Variables delivered to a run, as
shapes. A value is never returned or logged: only its length, a class, and an 8-hex fingerprint of any Salesforce
session in it (a sha256 prefix, so two variables carrying the same session can be matched and nothing can be read back).
"""
import hashlib
import json
import re
import urllib.error
import urllib.parse
import urllib.request

from robot.api import SkipExecution
from robot.libraries.BuiltIn import BuiltIn

SESSION = re.compile(r"00D[A-Za-z0-9]{12,15}![A-Za-z0-9._+/=-]{20,}")


def _shape(value):
    if value is None or value == "" or value == "NOT_SET":
        return "did not arrive" if value == "NOT_SET" or value is None else "empty", 0, None
    text = str(value)
    plain = urllib.parse.unquote(text)
    found = SESSION.search(plain)
    fingerprint = hashlib.sha256(found.group(0).encode()).hexdigest()[:8] if found else None
    if text.startswith("{$"):
        shape = "an unresolved expression"
    elif found and found.group(0) == plain.strip():
        shape = "a Salesforce session"
    elif found:
        shape = "a link with a Salesforce session"
    elif text.startswith("https://"):
        shape = "a URL: " + urllib.parse.urlsplit(text).netloc
    else:
        shape = "text"
    return shape, len(text), fingerprint


def describe_probe_variables(*names):
    """One line per variable: its shape, length, and whether a session in it is the loginUrl's session."""
    builtin = BuiltIn()
    _, _, login_fp = _shape(builtin.get_variable_value("${loginUrl}", ""))
    lines = []
    for name in names:
        shape, chars, fingerprint = _shape(builtin.get_variable_value("${%s}" % name, None))
        same = ""
        if fingerprint and name != "loginUrl":
            same = "; the SAME session as the loginUrl" if fingerprint == login_fp else "; NOT the loginUrl's session"
        lines.append(f"{name}: {shape}, {chars} chars{same}")
    return lines


def session_answers_soql(*pairs):
    """For the first (session variable, URL variable) pair that holds a session and an address: one SOQL call with
    that session. Returns the HTTP status and whether the org answering is the session's org."""
    builtin = BuiltIn()
    for session_name, url_name in zip(pairs[::2], pairs[1::2]):
        session = builtin.get_variable_value("${%s}" % session_name, "")
        url = builtin.get_variable_value("${%s}" % url_name, "")
        if SESSION.fullmatch(urllib.parse.unquote(session or "").strip()) and str(url).startswith("https://"):
            break
    else:
        raise SkipExecution("No Test record variable delivered a session and an address to call with.")
    host = re.match(r"https://[^/?]+", url).group(0)
    request = urllib.request.Request(f"{host}/services/data/v62.0/query?q=SELECT+Id+FROM+Organization",
                                     headers={"Authorization": "Bearer " + urllib.parse.unquote(session).strip()})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status, body = response.status, json.loads(response.read())
    except urllib.error.HTTPError as exc:
        return f"{session_name} at {url_name}: HTTP {exc.code}"
    org = body["records"][0]["Id"]
    match = org[:15] == urllib.parse.unquote(session).strip()[:15]
    return f"{session_name} at {url_name}: HTTP {status}; the org that answered is the session's org: {match}"
