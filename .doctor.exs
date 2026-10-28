%Doctor.Config{
  ignore_modules: [],
  ignore_paths: [],
  min_module_doc_coverage: 40,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 50,
  min_overall_spec_coverage: 0,
  min_overall_moduledoc_coverage: 100,
  raise: false,
  reporter: Doctor.Reporters.Full,
  #  FIXME: we are putting this as false until this bug is solved:
  # https://github.com/akoutmos/doctor/issues/50
  struct_type_spec_required: false,
  umbrella: false
}
