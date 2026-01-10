//! Error types for argument parsing.

pub const Error = error{
    /// Unknown argument provided
    UnknownArgument,
    /// Option value missing after flag
    MissingValue,
    /// Required argument not provided
    MissingRequired,
    /// Invalid value for argument type
    InvalidValue,
    /// Duplicate argument provided
    DuplicateArgument,
    /// Help requested (--help or -h)
    ShowHelp,
};
