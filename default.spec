%% Spec examples:
%%
%%   {suites, "tests", amp_SUITE}.
%%   {groups, "tests", amp_SUITE, [discovery]}.
%%   {groups, "tests", amp_SUITE, [discovery], {cases, [stream_feature_test]}}.
%%   {cases, "tests", amp_SUITE, [stream_feature_test]}.
%%
%% For more info see:
%% http://www.erlang.org/doc/apps/common_test/run_test_chapter.html#test_specifications

{suites, "tests", adhoc_SUITE}.
{suites, "tests", amp_SUITE}.
{suites, "tests", ejabberdctl_SUITE}.
{suites, "tests", last_SUITE}.
{suites, "tests", login_SUITE}.
{suites, "tests", muc_SUITE}.
{suites, "tests", mam_SUITE}.
{suites, "tests", offline_SUITE}.
{suites, "tests", presence_SUITE}.
{suites, "tests", privacy_SUITE}.
{suites, "tests", private_SUITE}.
{suites, "tests", sic_SUITE}.
{suites, "tests", sm_SUITE}.
{suites, "tests", shared_roster_SUITE}.
{suites, "tests", vcard_simple_SUITE}.
{suites, "tests", websockets_SUITE}.
{suites, "tests", metrics_c2s_SUITE}.
{suites, "tests", metrics_roster_SUITE}.
{suites, "tests", metrics_register_SUITE}.
{suites, "tests", metrics_session_SUITE}.
{suites, "tests", system_monitor_SUITE}.
{suites, "tests", carboncopy_SUITE}.
{suites, "tests", bosh_SUITE}.
{config, ["test.config"]}.
{logdir, "ct_report"}.
{ct_hooks, [ct_tty_hook]}.
