# This file configures doctor. The mix check command runs doctor, and doctor
# measures the documentation coverage of the modules in lib.
#
# Every threshold here is 100. Thus each module must have documentation, and
# each public function must have documentation and a spec. The default
# thresholds of doctor are much lower. The default for
# min_overall_doc_coverage is 50, and the default for min_overall_spec_coverage
# is 0. Those values let half of the documentation disappear before doctor
# reports a failure.
#
# Doctor examines only whether documentation exists. It does not examine the
# language of the documentation. The ASD-STE100 rules are in CLAUDE.md, and a
# reviewer must apply them.
%Doctor.Config{
  ignore_modules: [],
  ignore_paths: [],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 100,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false,
  failed: false
}
