"""CICD And CRT Dynamic Login, written in Python: the same login as resources/login_robot.robot, for teams that write
their keywords in Python. Only the sign-in lives here; every test step stays a stock QForce or QWeb keyword.

A suite imports this library OR login_robot.robot, never both (they define the same keyword):

    *** Settings ***
    Resource    ../resources/common.robot
    Library     ../resources/CicdDynamicLogin.py

    *** Test Cases ***
    Example
        CICD And CRT Dynamic Login
        ${org}=    QueryRecords    SELECT Id FROM Organization
        GoToRecord    ${org}[records][0][Id]

HOW IT WORKS
  Under Copado CI/CD, Copado passes one variable, ${loginUrl}: a frontdoor link with a live session in it,
  https://<org>/secur/frontdoor.jsp?sid=<session>. The login splits it in two:
    * the browser opens it, straight through Selenium, so the link is never a keyword argument the log could keep;
    * the session goes to QForce's API keywords. QForce has no keyword that takes a session, so the login sets the three
      values its API keywords read in QForce.keywords.rest_api (_token, instance_url and version_url; true in QForce
      2025.40 and 2026.39), then checks QForce answers from that session's org.
  Run on its own in CRT there is no session: JWTAuthenticate with the job's client_id / username / private_key, then
  JwtLogin.
  Either way, for the whole suite: ${INSTANCE} is the org's address, ${API} says whether QForce's API keywords can run,
  and ${login_url} is the org's address, so GoToRecord takes a bare record Id.

NEVER: log the loginUrl, the session or the JWT variables; call QForce's Revoke under CI/CD (it ends Copado's session
for every suite after it); declare client_id / username / private_key in a file (CRT supplies them; declared in a file,
they break Live Testing).
"""
import importlib
import re
import urllib.parse
from contextlib import contextmanager

from robot.api import logger
from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn

GENERIC_LOGIN_PAGE = re.compile(r"https://(login|test)\.salesforce\.com/?")


def dissect(login_url):
    """Copado's loginUrl in two parts: the org's address ('https://<host>') and the session after sid= ('' if none)."""
    host = (re.findall(r"https://[^/?]+", login_url or "") or [""])[0]
    found = re.search(r"[?&]sid=([^&]+)", login_url or "")
    return host, (urllib.parse.unquote(found.group(1)) if found else "")


def is_org_address(url):
    """True only for a bare org address someone set on the job: not empty, not a link with a session, and not a
    generic login page (login. or test.salesforce.com), which is not an org."""
    url = (url or "").strip()
    return bool(re.fullmatch(r"https://[^/?#\s]+/?", url)) and not GENERIC_LOGIN_PAGE.fullmatch(url)


@contextmanager
def logging_off():
    """Nothing reaches the log inside: not a keyword's arguments, not its return value."""
    previous = BuiltIn().set_log_level("NONE")
    try:
        yield
    finally:
        BuiltIn().set_log_level(previous)


@library(scope="SUITE", auto_keywords=False)
class CicdDynamicLogin:
    """One instance per suite, like the suite variables it sets."""

    def __init__(self):
        self.signed_in_with = None          # "cicd" or "jwt" once this suite has signed in

    @keyword("CICD And CRT Dynamic Login")
    def cicd_and_crt_dynamic_login(self):
        """Signs the browser AND QForce's API keywords in to one org, however the job was started. Sets ${INSTANCE},
        ${API} and ${login_url} for the suite. Called again in the same suite, it signs the browser back in as the same
        user (after JwtLoginAs)."""
        if self.signed_in_with:
            self._sign_the_browser_back_in()
            return
        builtin = BuiltIn()
        with logging_off():
            login_url = builtin.get_variable_value("${loginUrl}", "") or ""
            jwt = builtin.get_variable_value("${client_id}", "NOT_SET") != "NOT_SET"
        host, session = dissect(login_url)

        if session:                                         # Copado CI/CD
            self._open_in_browser(login_url)
            api = self._hand_session_to_qforce(host, session)
            if not api and jwt:
                api, _ = self._jwt_sign_in(custom_url=host)
            if not api:
                logger.warn(f"QForce cannot use the CI/CD session and the job's JWT variables do not sign in at {host}: "
                            "API checks are off.")
            self._signed_in("cicd", host, api)
            return

        if not jwt:                                         # run on its own in CRT
            raise AssertionError("No way to log in: no CI/CD session in the loginUrl and no "
                                 "client_id/username/private_key variables.")
        jwt_url = (builtin.get_variable_value("${jwt_url}", "") or "").strip().rstrip("/")
        if host:
            # a loginUrl without a session: an address set on the job, or a CI/CD credential that has expired
            logger.warn(f"The loginUrl carries no session: signing in with JWT at {host}.")
            ok, reason = self._jwt_sign_in(custom_url=host)
        elif jwt_url:
            ok, reason = self._jwt_sign_in(custom_url=jwt_url)
        else:
            ok, reason = self._jwt_sign_in(sandbox=True)
            if not ok:
                ok, reason = self._jwt_sign_in()
        if not ok:
            raise AssertionError(f"The job's JWT variables did not sign in: {reason}")
        builtin.run_keyword("QForce.JwtLogin")
        self._signed_in("jwt", builtin.run_keyword("QForce.GetInstanceUrl"), True)

    # ------------------------------------------------------------------------------------------- the steps
    @staticmethod
    def _open_in_browser(url):
        """Open a link that carries a session through Selenium itself: a link handed to a keyword (GoTo) is kept in the
        log as that keyword's argument."""
        from QWeb.internal import browser
        browser.get_current_browser().get(url)

    @staticmethod
    def _hand_session_to_qforce(host, session):
        """Give QForce's API keywords the CI/CD session, then check QForce answers from that session's org (a session
        starts with its org's 15-character Id). On any doubt, clear the session out of QForce and return False, so
        QForce never answers from another org."""
        rest = importlib.import_module("QForce.keywords.rest_api")
        try:
            rest._token = session
            rest.instance_url = host
            rest.version_url = rest._get_version_url(host, 30)
            org = BuiltIn().run_keyword("QForce.QueryRecords", "SELECT Id FROM Organization")
            if org["records"][0]["Id"][:15] == session[:15]:
                return True
            logger.warn("QForce did not answer from the CI/CD session's org, so the session is cleared out of QForce.")
        except Exception as exc:                            # a QForce release that changed these values
            logger.warn(f"QForce did not take the CI/CD session ({type(exc).__name__}): check this library against the "
                        "QForce version.")
        rest._token = None
        return False

    @staticmethod
    def _jwt_sign_in(sandbox=False, custom_url=None):
        """JWTAuthenticate with the job's JWT variables, logging off. They are passed by NAME: Robot keeps a keyword's
        arguments in the log as written, so '${private_key}' is what it keeps, never the key. Returns (True, '') or
        (False, Salesforce's reason)."""
        args = ["${client_id}", "${username}", "${private_key}"]
        if custom_url:
            args.append(f"custom_url={custom_url}")
        elif sandbox:
            args.append("sandbox=${True}")
        with logging_off():
            status, reason = BuiltIn().run_keyword_and_ignore_error("QForce.JWTAuthenticate", *args)
        # JWTAuthenticate returns the session it opened: hand back Salesforce's reason only when it failed
        return status == "PASS", ("" if status == "PASS" else reason)

    def _signed_in(self, how, instance, api):
        """Record how the suite signed in, and set INSTANCE, API and login_url for the whole suite. login_url IS
        Copado's loginUrl to Robot (it ignores case and underscores): an org address set on the job is kept; empty,
        Copado's link with its session, or a generic login page becomes the org's address."""
        builtin = BuiltIn()
        self.signed_in_with = how
        builtin.set_suite_variable("${INSTANCE}", instance)
        builtin.set_suite_variable("${API}", api)
        with logging_off():
            keep = is_org_address(builtin.get_variable_value("${login_url}", ""))
        if not keep:
            builtin.set_suite_variable("${login_url}", instance)
        how_text = "through the Copado CI/CD loginUrl" if how == "cicd" else "with JWT"
        logger.info(f"Logged in {how_text}: {instance} (API: {api})", also_console=True)

    def _sign_the_browser_back_in(self):
        """JWT: JwtLogin. CI/CD: rebuild the frontdoor link from the session QForce holds and open it in the browser."""
        if self.signed_in_with == "jwt":
            BuiltIn().run_keyword("QForce.JwtLogin")
            return
        token = importlib.import_module("QForce.keywords.rest_api")._token
        if not token:
            logger.warn("QForce holds no session to sign the browser back in with: the browser stays as it is.")
            return
        instance = BuiltIn().get_variable_value("${INSTANCE}")
        self._open_in_browser(f"{instance}/secur/frontdoor.jsp?sid={urllib.parse.quote(token)}")
