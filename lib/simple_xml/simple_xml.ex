defmodule SimpleXml do
  @moduledoc """
  This is a thin wrapper around the saxy library.  It leverages the DOM generated by saxy's
  SimpleForm parser and defines some basic operations on the DOM via the `XmlNode` module.

  The main benefit of using saxy's SimpleForm parsing is that it gives us a string presentation of
  the XML DOM, without exposing the users of this library with the
  [atom exhaustion vulernability](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/xmerl.html)
  of the xmerl library and any parsers based on it.
  """

  alias SimpleXml.XmlNode

  require Logger

  @type xml_attribute :: {String.t(), String.t()}
  @type xml_node :: {String.t(), [xml_attribute()], [tuple()]}
  @type public_key :: {atom(), any()}

  @doc """
  Parses an XML string to return a tuple representing the XML node.

  ## Examples

  ### Well-formed XMLs are successfully parsed

      iex> SimpleXml.parse(~S{<foo attr1="value1" attr2="value2">body</foo>})
      {:ok, {"foo", [{"attr1", "value1"}, {"attr2", "value2"}], ["body"]}}

  ### Malformed XMLs result in an error

      iex> SimpleXml.parse("<foo")
      {:error, %Saxy.ParseError{reason: {:token, :name_start_char}, binary: "<foo", position: 4}}
  """
  @spec parse(String.t()) :: {:ok, xml_node()} | {:error, Saxy.ParseError.t()}
  def parse(data) when is_binary(data),
    do: Saxy.SimpleForm.parse_string(data)

  @doc """
  Verifies the signature contained within the XML document represented by the given node.  For the
  sake of simplicity of implementation, this function expects the following to be true for the given
  XML document:
    * Signature conforms to the [XMLDSIG-CORE1](https://www.w3.org/TR/xmldsig-core1/) spec
    * Canonicalization method is [XML-ENC-C14N](http://www.w3.org/2001/10/xml-exc-c14n)
    * Transformation method includes [XMLDSIG-enveloped-signature](http://www.w3.org/2000/09/xmldsig#enveloped-signature)
    * Digest method is [XMLENC-SHA256](http://www.w3.org/2001/04/xmlenc#sha256)
    * Signature method is [XMLDSIG-SHA256](http://www.w3.org/2001/04/xmldsig-more#rsa-sha256)

  Arguments:
    * node: The xml_node corresponding to the document or portion of the document to be verified
    * public_key: The key to use for verifying the signature. Value matches the key argument given
        to `:pubic_key.verify/4`.  Please see document [here](https://www.erlang.org/doc/man/public_key.html#verify-4)
        for further details.

  ## Examples

  ### Verifies a valid signature via the given public key

      iex> cert_der = ~S(MIIDqDCCApCgAwIBAgIGAYj8lAYkMA0GCSqGSIb3DQEBCwUAMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTAeFw0yMzA2MjcxMTE3NTlaFw0zMzA2MjcxMTE4NTlaMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALTE7IRG+oQZBASQ7DY3yeTrwABdI2BgG2FXKSkTPk9enMwtyUyDXCOteOg18+//MA2UTvgSI+n0fiAh7Bi7cxpimnOaj/kcgvpdn+5wpEfSIDKAeEg9VIQf0fz/ks4XkrNxRh8ba6Z/ypOVR2TLozu8v6sjGCiqHSoiPl78KINHx9jMB3QGdTHRxsTzwFPGcUEvO7XvjxxMN9FLZdHkwtA6cZXDbHlAv+o4EbLIRqXFc3vF5rs3Fz+cgqZ3HVGm90TFFcbPbx/eKcvzyHdYt8P5pi364mijt9NKtNV9F9VdPz+Gp/rxlw0i/IWxV0/vBrW10HPd42krsOgHibxBYg8CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEArpYzZEoYcRo3YF7Ny4gdc8ODSlPPKIdLvwhUTGbPdzJU2ifxzE/KeTHGmFpjpakjDmmWsr2j9FGU/9U0SjqPmJHP5gYbjmz+tD3jeaEkIBDZpcYc+MveQaA7uDMILA2OUhHuFu0UJVjGxl2EIpxivC+IJ0RpBS5AERT6V91Fqv2Ylwb5sklhoXGDx9s+l+Ud1MLaewIvnUHdIRtC02bvlhjwt0pnICDtHMikvOiTXjTBJgl7X9Q51Gm636q9pJVjS1T0gR3cNt9JJE/foDdOK8JozRFtF4j14xegXLt7BVBIXuSOK6P1c09mCPQ1VJbcj01S1zfrvZ+RZvrxr/0aXQ==)
      iex> {:ok, cert} = cert_der |> Base.decode64!() |> X509.Certificate.from_der()
      iex> public_key = X509.Certificate.public_key(cert)
      iex> saml_response = "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz48c2FtbDJwOlJlc3BvbnNlIERlc3RpbmF0aW9uPSJodHRwczovL2xvY2FsLm1ieC5jb206NDAwMS9hdXRoL2FoZWFkL3NzbyIgSUQ9ImlkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiIElzc3VlSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBWZXJzaW9uPSIyLjAiIHhtbG5zOnNhbWwycD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnByb3RvY29sIj48c2FtbDI6SXNzdWVyIEZvcm1hdD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOm5hbWVpZC1mb3JtYXQ6ZW50aXR5IiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+aHR0cDovL3d3dy5va3RhLmNvbS9leGthNWhhNmJrblk2T2tkODVkNzwvc2FtbDI6SXNzdWVyPjxkczpTaWduYXR1cmUgeG1sbnM6ZHM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPjxkczpTaWduZWRJbmZvPjxkczpDYW5vbmljYWxpemF0aW9uTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8xMC94bWwtZXhjLWMxNG4jIi8+PGRzOlNpZ25hdHVyZU1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZHNpZy1tb3JlI3JzYS1zaGEyNTYiLz48ZHM6UmVmZXJlbmNlIFVSST0iI2lkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiPjxkczpUcmFuc2Zvcm1zPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSIvPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48L2RzOlRyYW5zZm9ybXM+PGRzOkRpZ2VzdE1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZW5jI3NoYTI1NiIvPjxkczpEaWdlc3RWYWx1ZT5tc1hWN3BvS2dWSjE1SmFzeU5NVndFRUNqMHJOOGVjeUdUb291WFd6L0drPTwvZHM6RGlnZXN0VmFsdWU+PC9kczpSZWZlcmVuY2U+PC9kczpTaWduZWRJbmZvPjxkczpTaWduYXR1cmVWYWx1ZT5nM1dIaXZCR2hQc01hMDMwaDlCVUlBV2FFckFXZDI4dURqQlVIUk9RK2VoS3dqcXhrQ1BsYzRaVXdyRitnbkZtdzJsdDgxbnBwbzVVMEVTbW4vQUdKNjBKMjBaeFZSZ2pzWnhLMUFoVnFyNDB1MHdBNmY2akNKaUpXbmJxSUdXWERYeWlrV08wLzRycU9kRDl3UDhEdzJQbWlvMit2TXNOSWxwTnl1MnlvQXoydXNsbi92RmVTWXRZNW1LMDk1eDd3VWNIYVcwb2NacE9VTEREalNiMHFHTjhWN1dnSnZGaEhQcURiTnBHMTFSQmNac0VxRnVsYUd6djJQdXU5aER5dStaMEhOcVQwKzNGMEkxVGluTUpHMzNQcXMyUnNva0NaTHh6MkdCNHdqZHBOVFJOTTdKN2loN0x5N2Y5a2RPTWFMbSs2YzkxN3puM2JKUDdWOUdiOWc9PTwvZHM6U2lnbmF0dXJlVmFsdWU+PGRzOktleUluZm8+PGRzOlg1MDlEYXRhPjxkczpYNTA5Q2VydGlmaWNhdGU+TUlJRHFEQ0NBcENnQXdJQkFnSUdBWWo4bEFZa01BMEdDU3FHU0liM0RRRUJDd1VBTUlHVU1Rc3dDUVlEVlFRR0V3SlZVekVUTUJFRwpBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0dBMVVFQ2d3RVQydDBZVEVVCk1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFY01Cb0dDU3FHU0liM0RRRUoKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVEFlRncweU16QTJNamN4TVRFM05UbGFGdzB6TXpBMk1qY3hNVEU0TlRsYU1JR1VNUXN3Q1FZRApWUVFHRXdKVlV6RVRNQkVHQTFVRUNBd0tRMkZzYVdadmNtNXBZVEVXTUJRR0ExVUVCd3dOVTJGdUlFWnlZVzVqYVhOamJ6RU5NQXNHCkExVUVDZ3dFVDJ0MFlURVVNQklHQTFVRUN3d0xVMU5QVUhKdmRtbGtaWEl4RlRBVEJnTlZCQU1NREdSbGRpMDBOVE0wT1Rrd05qRWMKTUJvR0NTcUdTSWIzRFFFSkFSWU5hVzVtYjBCdmEzUmhMbU52YlRDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQwpnZ0VCQUxURTdJUkcrb1FaQkFTUTdEWTN5ZVRyd0FCZEkyQmdHMkZYS1NrVFBrOWVuTXd0eVV5RFhDT3RlT2cxOCsvL01BMlVUdmdTCkkrbjBmaUFoN0JpN2N4cGltbk9hai9rY2d2cGRuKzV3cEVmU0lES0FlRWc5VklRZjBmei9rczRYa3JOeFJoOGJhNloveXBPVlIyVEwKb3p1OHY2c2pHQ2lxSFNvaVBsNzhLSU5IeDlqTUIzUUdkVEhSeHNUendGUEdjVUV2TzdYdmp4eE1OOUZMWmRIa3d0QTZjWlhEYkhsQQp2K280RWJMSVJxWEZjM3ZGNXJzM0Z6K2NncVozSFZHbTkwVEZGY2JQYngvZUtjdnp5SGRZdDhQNXBpMzY0bWlqdDlOS3ROVjlGOVZkClB6K0dwL3J4bHcwaS9JV3hWMC92QnJXMTBIUGQ0Mmtyc09nSGlieEJZZzhDQXdFQUFUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUEKcnBZelpFb1ljUm8zWUY3Tnk0Z2RjOE9EU2xQUEtJZEx2d2hVVEdiUGR6SlUyaWZ4ekUvS2VUSEdtRnBqcGFrakRtbVdzcjJqOUZHVQovOVUwU2pxUG1KSFA1Z1liam16K3REM2plYUVrSUJEWnBjWWMrTXZlUWFBN3VETUlMQTJPVWhIdUZ1MFVKVmpHeGwyRUlweGl2QytJCkowUnBCUzVBRVJUNlY5MUZxdjJZbHdiNXNrbGhvWEdEeDlzK2wrVWQxTUxhZXdJdm5VSGRJUnRDMDJidmxoand0MHBuSUNEdEhNaWsKdk9pVFhqVEJKZ2w3WDlRNTFHbTYzNnE5cEpWalMxVDBnUjNjTnQ5SkpFL2ZvRGRPSzhKb3pSRnRGNGoxNHhlZ1hMdDdCVkJJWHVTTwpLNlAxYzA5bUNQUTFWSmJjajAxUzF6ZnJ2WitSWnZyeHIvMGFYUT09PC9kczpYNTA5Q2VydGlmaWNhdGU+PC9kczpYNTA5RGF0YT48L2RzOktleUluZm8+PC9kczpTaWduYXR1cmU+PHNhbWwycDpTdGF0dXMgeG1sbnM6c2FtbDJwPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6cHJvdG9jb2wiPjxzYW1sMnA6U3RhdHVzQ29kZSBWYWx1ZT0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnN0YXR1czpTdWNjZXNzIi8+PC9zYW1sMnA6U3RhdHVzPjxzYW1sMjpBc3NlcnRpb24gSUQ9ImlkMjc3ODQwNDc4ODc3ODQ3MjgyMTE5MzE4OTUiIElzc3VlSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBWZXJzaW9uPSIyLjAiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj48c2FtbDI6SXNzdWVyIEZvcm1hdD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOm5hbWVpZC1mb3JtYXQ6ZW50aXR5IiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+aHR0cDovL3d3dy5va3RhLmNvbS9leGthNWhhNmJrblk2T2tkODVkNzwvc2FtbDI6SXNzdWVyPjxkczpTaWduYXR1cmUgeG1sbnM6ZHM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPjxkczpTaWduZWRJbmZvPjxkczpDYW5vbmljYWxpemF0aW9uTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8xMC94bWwtZXhjLWMxNG4jIi8+PGRzOlNpZ25hdHVyZU1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZHNpZy1tb3JlI3JzYS1zaGEyNTYiLz48ZHM6UmVmZXJlbmNlIFVSST0iI2lkMjc3ODQwNDc4ODc3ODQ3MjgyMTE5MzE4OTUiPjxkczpUcmFuc2Zvcm1zPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSIvPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48L2RzOlRyYW5zZm9ybXM+PGRzOkRpZ2VzdE1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZW5jI3NoYTI1NiIvPjxkczpEaWdlc3RWYWx1ZT42b3Ztd3BWNk00bHdBQ3BGZ0tqVm0rNlZ5U0t0dE9iVTF2Y2tvZlVWa2ZBPTwvZHM6RGlnZXN0VmFsdWU+PC9kczpSZWZlcmVuY2U+PC9kczpTaWduZWRJbmZvPjxkczpTaWduYXR1cmVWYWx1ZT5QdGhLcG1TY2k3OTdERExvTXR1TUJHNjgvbzZlcDFSSWxZR0RhRVR6Q1E1a0ZUdmQ3MWJ3RWpjOWl2UVdlU3VHM1U4aUM2THQvN0hmWEpUVDBLeWkvU2laa3pIZkl1bElKbTVQTm9memV1dXVFQVlyMFBoeUpidkJHUk44RWF0UEwwVjNsdlhPMU9YaHcxU2ltYlMwZEdoQkdCM1ovNEptajNBMGdGbmx5TkpOLzc4eFgrYlB1eEJLeFFYcFY5TTEwTnJLRUYrbzc1TVA3bm4xOW5KM002bG93SEFHZ3RhRFg5dTNGYTJ3Lzh4QXFGTnQ2NHdaMERQYWltQWl0RFBKdnRIL3VVN3k0cm1lUit0cXpqdnNHR3BtODNjNVNzd1dEZ1p4alBDSVdHRVRaVVdHQ0Rwb25WVzdUR0JuNDR4b1ZZUEhERStJcWJyWDdUVXIySFFoUGc9PTwvZHM6U2lnbmF0dXJlVmFsdWU+PGRzOktleUluZm8+PGRzOlg1MDlEYXRhPjxkczpYNTA5Q2VydGlmaWNhdGU+TUlJRHFEQ0NBcENnQXdJQkFnSUdBWWo4bEFZa01BMEdDU3FHU0liM0RRRUJDd1VBTUlHVU1Rc3dDUVlEVlFRR0V3SlZVekVUTUJFRwpBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0dBMVVFQ2d3RVQydDBZVEVVCk1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFY01Cb0dDU3FHU0liM0RRRUoKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVEFlRncweU16QTJNamN4TVRFM05UbGFGdzB6TXpBMk1qY3hNVEU0TlRsYU1JR1VNUXN3Q1FZRApWUVFHRXdKVlV6RVRNQkVHQTFVRUNBd0tRMkZzYVdadmNtNXBZVEVXTUJRR0ExVUVCd3dOVTJGdUlFWnlZVzVqYVhOamJ6RU5NQXNHCkExVUVDZ3dFVDJ0MFlURVVNQklHQTFVRUN3d0xVMU5QVUhKdmRtbGtaWEl4RlRBVEJnTlZCQU1NREdSbGRpMDBOVE0wT1Rrd05qRWMKTUJvR0NTcUdTSWIzRFFFSkFSWU5hVzVtYjBCdmEzUmhMbU52YlRDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQwpnZ0VCQUxURTdJUkcrb1FaQkFTUTdEWTN5ZVRyd0FCZEkyQmdHMkZYS1NrVFBrOWVuTXd0eVV5RFhDT3RlT2cxOCsvL01BMlVUdmdTCkkrbjBmaUFoN0JpN2N4cGltbk9hai9rY2d2cGRuKzV3cEVmU0lES0FlRWc5VklRZjBmei9rczRYa3JOeFJoOGJhNloveXBPVlIyVEwKb3p1OHY2c2pHQ2lxSFNvaVBsNzhLSU5IeDlqTUIzUUdkVEhSeHNUendGUEdjVUV2TzdYdmp4eE1OOUZMWmRIa3d0QTZjWlhEYkhsQQp2K280RWJMSVJxWEZjM3ZGNXJzM0Z6K2NncVozSFZHbTkwVEZGY2JQYngvZUtjdnp5SGRZdDhQNXBpMzY0bWlqdDlOS3ROVjlGOVZkClB6K0dwL3J4bHcwaS9JV3hWMC92QnJXMTBIUGQ0Mmtyc09nSGlieEJZZzhDQXdFQUFUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUEKcnBZelpFb1ljUm8zWUY3Tnk0Z2RjOE9EU2xQUEtJZEx2d2hVVEdiUGR6SlUyaWZ4ekUvS2VUSEdtRnBqcGFrakRtbVdzcjJqOUZHVQovOVUwU2pxUG1KSFA1Z1liam16K3REM2plYUVrSUJEWnBjWWMrTXZlUWFBN3VETUlMQTJPVWhIdUZ1MFVKVmpHeGwyRUlweGl2QytJCkowUnBCUzVBRVJUNlY5MUZxdjJZbHdiNXNrbGhvWEdEeDlzK2wrVWQxTUxhZXdJdm5VSGRJUnRDMDJidmxoand0MHBuSUNEdEhNaWsKdk9pVFhqVEJKZ2w3WDlRNTFHbTYzNnE5cEpWalMxVDBnUjNjTnQ5SkpFL2ZvRGRPSzhKb3pSRnRGNGoxNHhlZ1hMdDdCVkJJWHVTTwpLNlAxYzA5bUNQUTFWSmJjajAxUzF6ZnJ2WitSWnZyeHIvMGFYUT09PC9kczpYNTA5Q2VydGlmaWNhdGU+PC9kczpYNTA5RGF0YT48L2RzOktleUluZm8+PC9kczpTaWduYXR1cmU+PHNhbWwyOlN1YmplY3QgeG1sbnM6c2FtbDI9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDphc3NlcnRpb24iPjxzYW1sMjpOYW1lSUQgRm9ybWF0PSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoxLjE6bmFtZWlkLWZvcm1hdDp1bnNwZWNpZmllZCI+ZGouamFpbjwvc2FtbDI6TmFtZUlEPjxzYW1sMjpTdWJqZWN0Q29uZmlybWF0aW9uIE1ldGhvZD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmNtOmJlYXJlciI+PHNhbWwyOlN1YmplY3RDb25maXJtYXRpb25EYXRhIE5vdE9uT3JBZnRlcj0iMjAyMy0wNy0xMFQxMzo0NToyOS42NTlaIiBSZWNpcGllbnQ9Imh0dHBzOi8vbG9jYWwubWJ4LmNvbTo0MDAxL2F1dGgvYWhlYWQvc3NvIi8+PC9zYW1sMjpTdWJqZWN0Q29uZmlybWF0aW9uPjwvc2FtbDI6U3ViamVjdD48c2FtbDI6Q29uZGl0aW9ucyBOb3RCZWZvcmU9IjIwMjMtMDctMTBUMTM6MzU6MjkuNjU5WiIgTm90T25PckFmdGVyPSIyMDIzLTA3LTEwVDEzOjQ1OjI5LjY1OVoiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj48c2FtbDI6QXVkaWVuY2VSZXN0cmljdGlvbj48c2FtbDI6QXVkaWVuY2U+eHFPNTJDTkVMZDBoVkI5dmFYMWRfZGN3dVlBeEdVU3I8L3NhbWwyOkF1ZGllbmNlPjwvc2FtbDI6QXVkaWVuY2VSZXN0cmljdGlvbj48L3NhbWwyOkNvbmRpdGlvbnM+PHNhbWwyOkF1dGhuU3RhdGVtZW50IEF1dGhuSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBTZXNzaW9uSW5kZXg9ImlkMTY4ODk5NjQyOTY1Ny4xMTQ1MDMyMDEyIiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+PHNhbWwyOkF1dGhuQ29udGV4dD48c2FtbDI6QXV0aG5Db250ZXh0Q2xhc3NSZWY+dXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFjOmNsYXNzZXM6UGFzc3dvcmRQcm90ZWN0ZWRUcmFuc3BvcnQ8L3NhbWwyOkF1dGhuQ29udGV4dENsYXNzUmVmPjwvc2FtbDI6QXV0aG5Db250ZXh0Pjwvc2FtbDI6QXV0aG5TdGF0ZW1lbnQ+PC9zYW1sMjpBc3NlcnRpb24+PC9zYW1sMnA6UmVzcG9uc2U+"
      iex> {:ok, saml_body} = saml_response |> Base.decode64()
      iex> {:ok, root} = SimpleXml.parse(saml_body)
      iex> SimpleXml.verify(root, public_key)
      :ok

  ### Verification fails if the digest doesn't match the expected value

      iex> cert_der = ~S(MIIDqDCCApCgAwIBAgIGAYj8lAYkMA0GCSqGSIb3DQEBCwUAMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTAeFw0yMzA2MjcxMTE3NTlaFw0zMzA2MjcxMTE4NTlaMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALTE7IRG+oQZBASQ7DY3yeTrwABdI2BgG2FXKSkTPk9enMwtyUyDXCOteOg18+//MA2UTvgSI+n0fiAh7Bi7cxpimnOaj/kcgvpdn+5wpEfSIDKAeEg9VIQf0fz/ks4XkrNxRh8ba6Z/ypOVR2TLozu8v6sjGCiqHSoiPl78KINHx9jMB3QGdTHRxsTzwFPGcUEvO7XvjxxMN9FLZdHkwtA6cZXDbHlAv+o4EbLIRqXFc3vF5rs3Fz+cgqZ3HVGm90TFFcbPbx/eKcvzyHdYt8P5pi364mijt9NKtNV9F9VdPz+Gp/rxlw0i/IWxV0/vBrW10HPd42krsOgHibxBYg8CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEArpYzZEoYcRo3YF7Ny4gdc8ODSlPPKIdLvwhUTGbPdzJU2ifxzE/KeTHGmFpjpakjDmmWsr2j9FGU/9U0SjqPmJHP5gYbjmz+tD3jeaEkIBDZpcYc+MveQaA7uDMILA2OUhHuFu0UJVjGxl2EIpxivC+IJ0RpBS5AERT6V91Fqv2Ylwb5sklhoXGDx9s+l+Ud1MLaewIvnUHdIRtC02bvlhjwt0pnICDtHMikvOiTXjTBJgl7X9Q51Gm636q9pJVjS1T0gR3cNt9JJE/foDdOK8JozRFtF4j14xegXLt7BVBIXuSOK6P1c09mCPQ1VJbcj01S1zfrvZ+RZvrxr/0aXQ==)
      iex> {:ok, cert} = cert_der |> Base.decode64!() |> X509.Certificate.from_der()
      iex> public_key = X509.Certificate.public_key(cert)
      iex> saml_response = "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz48c2FtbDJwOlJlc3BvbnNlIERlc3RpbmF0aW9uPSJodHRwczovL2xvY2FsLm1ieC5jb206NDAwMS9hdXRoL2FoZWFkL3NzbyIgSUQ9ImlkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiIElzc3VlSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBWZXJzaW9uPSIyLjAiIHhtbG5zOnNhbWwycD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnByb3RvY29sIj48c2FtbDI6SXNzdWVyIEZvcm1hdD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOm5hbWVpZC1mb3JtYXQ6ZW50aXR5IiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+aHR0cDovL3d3dy5va3RhLmNvbS9leGthNWhhNmJrblk2T2tkODVkNzwvc2FtbDI6SXNzdWVyPjxkczpTaWduYXR1cmUgeG1sbnM6ZHM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPjxkczpTaWduZWRJbmZvPjxkczpDYW5vbmljYWxpemF0aW9uTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8xMC94bWwtZXhjLWMxNG4jIi8+PGRzOlNpZ25hdHVyZU1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZHNpZy1tb3JlI3JzYS1zaGEyNTYiLz48ZHM6UmVmZXJlbmNlIFVSST0iI2lkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiPjxkczpUcmFuc2Zvcm1zPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSIvPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48L2RzOlRyYW5zZm9ybXM+PGRzOkRpZ2VzdE1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZW5jI3NoYTI1NiIvPjxkczpEaWdlc3RWYWx1ZT5CQURfRElHRVNUPC9kczpEaWdlc3RWYWx1ZT48L2RzOlJlZmVyZW5jZT48L2RzOlNpZ25lZEluZm8+PGRzOlNpZ25hdHVyZVZhbHVlPmczV0hpdkJHaFBzTWEwMzBoOUJVSUFXYUVyQVdkMjh1RGpCVUhST1ErZWhLd2pxeGtDUGxjNFpVd3JGK2duRm13Mmx0ODFucHBvNVUwRVNtbi9BR0o2MEoyMFp4VlJnanNaeEsxQWhWcXI0MHUwd0E2ZjZqQ0ppSlduYnFJR1dYRFh5aWtXTzAvNHJxT2REOXdQOER3MlBtaW8yK3ZNc05JbHBOeXUyeW9BejJ1c2xuL3ZGZVNZdFk1bUswOTV4N3dVY0hhVzBvY1pwT1VMRERqU2IwcUdOOFY3V2dKdkZoSFBxRGJOcEcxMVJCY1pzRXFGdWxhR3p2MlB1dTloRHl1K1owSE5xVDArM0YwSTFUaW5NSkczM1BxczJSc29rQ1pMeHoyR0I0d2pkcE5UUk5NN0o3aWg3THk3ZjlrZE9NYUxtKzZjOTE3em4zYkpQN1Y5R2I5Zz09PC9kczpTaWduYXR1cmVWYWx1ZT48ZHM6S2V5SW5mbz48ZHM6WDUwOURhdGE+PGRzOlg1MDlDZXJ0aWZpY2F0ZT5NSUlEcURDQ0FwQ2dBd0lCQWdJR0FZajhsQVlrTUEwR0NTcUdTSWIzRFFFQkN3VUFNSUdVTVFzd0NRWURWUVFHRXdKVlV6RVRNQkVHCkExVUVDQXdLUTJGc2FXWnZjbTVwWVRFV01CUUdBMVVFQnd3TlUyRnVJRVp5WVc1amFYTmpiekVOTUFzR0ExVUVDZ3dFVDJ0MFlURVUKTUJJR0ExVUVDd3dMVTFOUFVISnZkbWxrWlhJeEZUQVRCZ05WQkFNTURHUmxkaTAwTlRNME9Ua3dOakVjTUJvR0NTcUdTSWIzRFFFSgpBUllOYVc1bWIwQnZhM1JoTG1OdmJUQWVGdzB5TXpBMk1qY3hNVEUzTlRsYUZ3MHpNekEyTWpjeE1URTROVGxhTUlHVU1Rc3dDUVlEClZRUUdFd0pWVXpFVE1CRUdBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0cKQTFVRUNnd0VUMnQwWVRFVU1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFYwpNQm9HQ1NxR1NJYjNEUUVKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVENDQVNJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dFUEFEQ0NBUW9DCmdnRUJBTFRFN0lSRytvUVpCQVNRN0RZM3llVHJ3QUJkSTJCZ0cyRlhLU2tUUGs5ZW5Nd3R5VXlEWENPdGVPZzE4Ky8vTUEyVVR2Z1MKSStuMGZpQWg3Qmk3Y3hwaW1uT2FqL2tjZ3ZwZG4rNXdwRWZTSURLQWVFZzlWSVFmMGZ6L2tzNFhrck54Umg4YmE2Wi95cE9WUjJUTApvenU4djZzakdDaXFIU29pUGw3OEtJTkh4OWpNQjNRR2RUSFJ4c1R6d0ZQR2NVRXZPN1h2anh4TU45RkxaZEhrd3RBNmNaWERiSGxBCnYrbzRFYkxJUnFYRmMzdkY1cnMzRnorY2dxWjNIVkdtOTBURkZjYlBieC9lS2N2enlIZFl0OFA1cGkzNjRtaWp0OU5LdE5WOUY5VmQKUHorR3AvcnhsdzBpL0lXeFYwL3ZCclcxMEhQZDQya3JzT2dIaWJ4QllnOENBd0VBQVRBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQpycFl6WkVvWWNSbzNZRjdOeTRnZGM4T0RTbFBQS0lkTHZ3aFVUR2JQZHpKVTJpZnh6RS9LZVRIR21GcGpwYWtqRG1tV3NyMmo5RkdVCi85VTBTanFQbUpIUDVnWWJqbXordEQzamVhRWtJQkRacGNZYytNdmVRYUE3dURNSUxBMk9VaEh1RnUwVUpWakd4bDJFSXB4aXZDK0kKSjBScEJTNUFFUlQ2VjkxRnF2Mllsd2I1c2tsaG9YR0R4OXMrbCtVZDFNTGFld0l2blVIZElSdEMwMmJ2bGhqd3QwcG5JQ0R0SE1pawp2T2lUWGpUQkpnbDdYOVE1MUdtNjM2cTlwSlZqUzFUMGdSM2NOdDlKSkUvZm9EZE9LOEpvelJGdEY0ajE0eGVnWEx0N0JWQklYdVNPCks2UDFjMDltQ1BRMVZKYmNqMDFTMXpmcnZaK1JadnJ4ci8wYVhRPT08L2RzOlg1MDlDZXJ0aWZpY2F0ZT48L2RzOlg1MDlEYXRhPjwvZHM6S2V5SW5mbz48L2RzOlNpZ25hdHVyZT48c2FtbDJwOlN0YXR1cyB4bWxuczpzYW1sMnA9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDpwcm90b2NvbCI+PHNhbWwycDpTdGF0dXNDb2RlIFZhbHVlPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6c3RhdHVzOlN1Y2Nlc3MiLz48L3NhbWwycDpTdGF0dXM+PHNhbWwyOkFzc2VydGlvbiBJRD0iaWQyNzc4NDA0Nzg4Nzc4NDcyODIxMTkzMTg5NSIgSXNzdWVJbnN0YW50PSIyMDIzLTA3LTEwVDEzOjQwOjI5LjY1OFoiIFZlcnNpb249IjIuMCIgeG1sbnM6c2FtbDI9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDphc3NlcnRpb24iPjxzYW1sMjpJc3N1ZXIgRm9ybWF0PSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6bmFtZWlkLWZvcm1hdDplbnRpdHkiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj5odHRwOi8vd3d3Lm9rdGEuY29tL2V4a2E1aGE2YmtuWTZPa2Q4NWQ3PC9zYW1sMjpJc3N1ZXI+PGRzOlNpZ25hdHVyZSB4bWxuczpkcz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnIyI+PGRzOlNpZ25lZEluZm8+PGRzOkNhbm9uaWNhbGl6YXRpb25NZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48ZHM6U2lnbmF0dXJlTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8wNC94bWxkc2lnLW1vcmUjcnNhLXNoYTI1NiIvPjxkczpSZWZlcmVuY2UgVVJJPSIjaWQyNzc4NDA0Nzg4Nzc4NDcyODIxMTkzMTg5NSI+PGRzOlRyYW5zZm9ybXM+PGRzOlRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyNlbnZlbG9wZWQtc2lnbmF0dXJlIi8+PGRzOlRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMTAveG1sLWV4Yy1jMTRuIyIvPjwvZHM6VHJhbnNmb3Jtcz48ZHM6RGlnZXN0TWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8wNC94bWxlbmMjc2hhMjU2Ii8+PGRzOkRpZ2VzdFZhbHVlPjZvdm13cFY2TTRsd0FDcEZnS2pWbSs2VnlTS3R0T2JVMXZja29mVVZrZkE9PC9kczpEaWdlc3RWYWx1ZT48L2RzOlJlZmVyZW5jZT48L2RzOlNpZ25lZEluZm8+PGRzOlNpZ25hdHVyZVZhbHVlPlB0aEtwbVNjaTc5N0RETG9NdHVNQkc2OC9vNmVwMVJJbFlHRGFFVHpDUTVrRlR2ZDcxYndFamM5aXZRV2VTdUczVThpQzZMdC83SGZYSlRUMEt5aS9TaVprekhmSXVsSUptNVBOb2Z6ZXV1dUVBWXIwUGh5SmJ2QkdSTjhFYXRQTDBWM2x2WE8xT1hodzFTaW1iUzBkR2hCR0IzWi80Sm1qM0EwZ0ZubHlOSk4vNzh4WCtiUHV4Qkt4UVhwVjlNMTBOcktFRitvNzVNUDdubjE5bkozTTZsb3dIQUdndGFEWDl1M0ZhMncvOHhBcUZOdDY0d1owRFBhaW1BaXREUEp2dEgvdVU3eTRybWVSK3Rxemp2c0dHcG04M2M1U3N3V0RnWnhqUENJV0dFVFpVV0dDRHBvblZXN1RHQm40NHhvVllQSERFK0lxYnJYN1RVcjJIUWhQZz09PC9kczpTaWduYXR1cmVWYWx1ZT48ZHM6S2V5SW5mbz48ZHM6WDUwOURhdGE+PGRzOlg1MDlDZXJ0aWZpY2F0ZT5NSUlEcURDQ0FwQ2dBd0lCQWdJR0FZajhsQVlrTUEwR0NTcUdTSWIzRFFFQkN3VUFNSUdVTVFzd0NRWURWUVFHRXdKVlV6RVRNQkVHCkExVUVDQXdLUTJGc2FXWnZjbTVwWVRFV01CUUdBMVVFQnd3TlUyRnVJRVp5WVc1amFYTmpiekVOTUFzR0ExVUVDZ3dFVDJ0MFlURVUKTUJJR0ExVUVDd3dMVTFOUFVISnZkbWxrWlhJeEZUQVRCZ05WQkFNTURHUmxkaTAwTlRNME9Ua3dOakVjTUJvR0NTcUdTSWIzRFFFSgpBUllOYVc1bWIwQnZhM1JoTG1OdmJUQWVGdzB5TXpBMk1qY3hNVEUzTlRsYUZ3MHpNekEyTWpjeE1URTROVGxhTUlHVU1Rc3dDUVlEClZRUUdFd0pWVXpFVE1CRUdBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0cKQTFVRUNnd0VUMnQwWVRFVU1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFYwpNQm9HQ1NxR1NJYjNEUUVKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVENDQVNJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dFUEFEQ0NBUW9DCmdnRUJBTFRFN0lSRytvUVpCQVNRN0RZM3llVHJ3QUJkSTJCZ0cyRlhLU2tUUGs5ZW5Nd3R5VXlEWENPdGVPZzE4Ky8vTUEyVVR2Z1MKSStuMGZpQWg3Qmk3Y3hwaW1uT2FqL2tjZ3ZwZG4rNXdwRWZTSURLQWVFZzlWSVFmMGZ6L2tzNFhrck54Umg4YmE2Wi95cE9WUjJUTApvenU4djZzakdDaXFIU29pUGw3OEtJTkh4OWpNQjNRR2RUSFJ4c1R6d0ZQR2NVRXZPN1h2anh4TU45RkxaZEhrd3RBNmNaWERiSGxBCnYrbzRFYkxJUnFYRmMzdkY1cnMzRnorY2dxWjNIVkdtOTBURkZjYlBieC9lS2N2enlIZFl0OFA1cGkzNjRtaWp0OU5LdE5WOUY5VmQKUHorR3AvcnhsdzBpL0lXeFYwL3ZCclcxMEhQZDQya3JzT2dIaWJ4QllnOENBd0VBQVRBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQpycFl6WkVvWWNSbzNZRjdOeTRnZGM4T0RTbFBQS0lkTHZ3aFVUR2JQZHpKVTJpZnh6RS9LZVRIR21GcGpwYWtqRG1tV3NyMmo5RkdVCi85VTBTanFQbUpIUDVnWWJqbXordEQzamVhRWtJQkRacGNZYytNdmVRYUE3dURNSUxBMk9VaEh1RnUwVUpWakd4bDJFSXB4aXZDK0kKSjBScEJTNUFFUlQ2VjkxRnF2Mllsd2I1c2tsaG9YR0R4OXMrbCtVZDFNTGFld0l2blVIZElSdEMwMmJ2bGhqd3QwcG5JQ0R0SE1pawp2T2lUWGpUQkpnbDdYOVE1MUdtNjM2cTlwSlZqUzFUMGdSM2NOdDlKSkUvZm9EZE9LOEpvelJGdEY0ajE0eGVnWEx0N0JWQklYdVNPCks2UDFjMDltQ1BRMVZKYmNqMDFTMXpmcnZaK1JadnJ4ci8wYVhRPT08L2RzOlg1MDlDZXJ0aWZpY2F0ZT48L2RzOlg1MDlEYXRhPjwvZHM6S2V5SW5mbz48L2RzOlNpZ25hdHVyZT48c2FtbDI6U3ViamVjdCB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+PHNhbWwyOk5hbWVJRCBGb3JtYXQ9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjEuMTpuYW1laWQtZm9ybWF0OnVuc3BlY2lmaWVkIj5kai5qYWluPC9zYW1sMjpOYW1lSUQ+PHNhbWwyOlN1YmplY3RDb25maXJtYXRpb24gTWV0aG9kPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6Y206YmVhcmVyIj48c2FtbDI6U3ViamVjdENvbmZpcm1hdGlvbkRhdGEgTm90T25PckFmdGVyPSIyMDIzLTA3LTEwVDEzOjQ1OjI5LjY1OVoiIFJlY2lwaWVudD0iaHR0cHM6Ly9sb2NhbC5tYnguY29tOjQwMDEvYXV0aC9haGVhZC9zc28iLz48L3NhbWwyOlN1YmplY3RDb25maXJtYXRpb24+PC9zYW1sMjpTdWJqZWN0PjxzYW1sMjpDb25kaXRpb25zIE5vdEJlZm9yZT0iMjAyMy0wNy0xMFQxMzozNToyOS42NTlaIiBOb3RPbk9yQWZ0ZXI9IjIwMjMtMDctMTBUMTM6NDU6MjkuNjU5WiIgeG1sbnM6c2FtbDI9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDphc3NlcnRpb24iPjxzYW1sMjpBdWRpZW5jZVJlc3RyaWN0aW9uPjxzYW1sMjpBdWRpZW5jZT54cU81MkNORUxkMGhWQjl2YVgxZF9kY3d1WUF4R1VTcjwvc2FtbDI6QXVkaWVuY2U+PC9zYW1sMjpBdWRpZW5jZVJlc3RyaWN0aW9uPjwvc2FtbDI6Q29uZGl0aW9ucz48c2FtbDI6QXV0aG5TdGF0ZW1lbnQgQXV0aG5JbnN0YW50PSIyMDIzLTA3LTEwVDEzOjQwOjI5LjY1OFoiIFNlc3Npb25JbmRleD0iaWQxNjg4OTk2NDI5NjU3LjExNDUwMzIwMTIiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj48c2FtbDI6QXV0aG5Db250ZXh0PjxzYW1sMjpBdXRobkNvbnRleHRDbGFzc1JlZj51cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YWM6Y2xhc3NlczpQYXNzd29yZFByb3RlY3RlZFRyYW5zcG9ydDwvc2FtbDI6QXV0aG5Db250ZXh0Q2xhc3NSZWY+PC9zYW1sMjpBdXRobkNvbnRleHQ+PC9zYW1sMjpBdXRoblN0YXRlbWVudD48L3NhbWwyOkFzc2VydGlvbj48L3NhbWwycDpSZXNwb25zZT4="
      iex> {:ok, saml_body} = saml_response |> Base.decode64()
      iex> {:ok, root} = SimpleXml.parse(saml_body)
      iex> SimpleXml.verify(root, public_key)
      {:error, :digest_verification_failed}

  ### Verification fails if the signature doesn't match the expected value

      iex> cert_der = ~S(MIIDqDCCApCgAwIBAgIGAYj8lAYkMA0GCSqGSIb3DQEBCwUAMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTAeFw0yMzA2MjcxMTE3NTlaFw0zMzA2MjcxMTE4NTlaMIGUMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFTATBgNVBAMMDGRldi00NTM0OTkwNjEcMBoGCSqGSIb3DQEJARYNaW5mb0Bva3RhLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALTE7IRG+oQZBASQ7DY3yeTrwABdI2BgG2FXKSkTPk9enMwtyUyDXCOteOg18+//MA2UTvgSI+n0fiAh7Bi7cxpimnOaj/kcgvpdn+5wpEfSIDKAeEg9VIQf0fz/ks4XkrNxRh8ba6Z/ypOVR2TLozu8v6sjGCiqHSoiPl78KINHx9jMB3QGdTHRxsTzwFPGcUEvO7XvjxxMN9FLZdHkwtA6cZXDbHlAv+o4EbLIRqXFc3vF5rs3Fz+cgqZ3HVGm90TFFcbPbx/eKcvzyHdYt8P5pi364mijt9NKtNV9F9VdPz+Gp/rxlw0i/IWxV0/vBrW10HPd42krsOgHibxBYg8CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEArpYzZEoYcRo3YF7Ny4gdc8ODSlPPKIdLvwhUTGbPdzJU2ifxzE/KeTHGmFpjpakjDmmWsr2j9FGU/9U0SjqPmJHP5gYbjmz+tD3jeaEkIBDZpcYc+MveQaA7uDMILA2OUhHuFu0UJVjGxl2EIpxivC+IJ0RpBS5AERT6V91Fqv2Ylwb5sklhoXGDx9s+l+Ud1MLaewIvnUHdIRtC02bvlhjwt0pnICDtHMikvOiTXjTBJgl7X9Q51Gm636q9pJVjS1T0gR3cNt9JJE/foDdOK8JozRFtF4j14xegXLt7BVBIXuSOK6P1c09mCPQ1VJbcj01S1zfrvZ+RZvrxr/0aXQ==)
      iex> {:ok, cert} = cert_der |> Base.decode64!() |> X509.Certificate.from_der()
      iex> public_key = X509.Certificate.public_key(cert)
      iex> saml_response = "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz48c2FtbDJwOlJlc3BvbnNlIERlc3RpbmF0aW9uPSJodHRwczovL2xvY2FsLm1ieC5jb206NDAwMS9hdXRoL2FoZWFkL3NzbyIgSUQ9ImlkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiIElzc3VlSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBWZXJzaW9uPSIyLjAiIHhtbG5zOnNhbWwycD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnByb3RvY29sIj48c2FtbDI6SXNzdWVyIEZvcm1hdD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOm5hbWVpZC1mb3JtYXQ6ZW50aXR5IiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+aHR0cDovL3d3dy5va3RhLmNvbS9leGthNWhhNmJrblk2T2tkODVkNzwvc2FtbDI6SXNzdWVyPjxkczpTaWduYXR1cmUgeG1sbnM6ZHM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPjxkczpTaWduZWRJbmZvPjxkczpDYW5vbmljYWxpemF0aW9uTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8xMC94bWwtZXhjLWMxNG4jIi8+PGRzOlNpZ25hdHVyZU1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZHNpZy1tb3JlI3JzYS1zaGEyNTYiLz48ZHM6UmVmZXJlbmNlIFVSST0iI2lkMjc3ODQwNDc4ODc1OTE3NzI4MTU4NDY3MDMiPjxkczpUcmFuc2Zvcm1zPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSIvPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48L2RzOlRyYW5zZm9ybXM+PGRzOkRpZ2VzdE1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZW5jI3NoYTI1NiIvPjxkczpEaWdlc3RWYWx1ZT5tc1hWN3BvS2dWSjE1SmFzeU5NVndFRUNqMHJOOGVjeUdUb291WFd6L0drPTwvZHM6RGlnZXN0VmFsdWU+PC9kczpSZWZlcmVuY2U+PC9kczpTaWduZWRJbmZvPjxkczpTaWduYXR1cmVWYWx1ZT5Ra0ZFWDFOSlIwNUJWRlZTUlE9PTwvZHM6U2lnbmF0dXJlVmFsdWU+PGRzOktleUluZm8+PGRzOlg1MDlEYXRhPjxkczpYNTA5Q2VydGlmaWNhdGU+TUlJRHFEQ0NBcENnQXdJQkFnSUdBWWo4bEFZa01BMEdDU3FHU0liM0RRRUJDd1VBTUlHVU1Rc3dDUVlEVlFRR0V3SlZVekVUTUJFRwpBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0dBMVVFQ2d3RVQydDBZVEVVCk1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFY01Cb0dDU3FHU0liM0RRRUoKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVEFlRncweU16QTJNamN4TVRFM05UbGFGdzB6TXpBMk1qY3hNVEU0TlRsYU1JR1VNUXN3Q1FZRApWUVFHRXdKVlV6RVRNQkVHQTFVRUNBd0tRMkZzYVdadmNtNXBZVEVXTUJRR0ExVUVCd3dOVTJGdUlFWnlZVzVqYVhOamJ6RU5NQXNHCkExVUVDZ3dFVDJ0MFlURVVNQklHQTFVRUN3d0xVMU5QVUhKdmRtbGtaWEl4RlRBVEJnTlZCQU1NREdSbGRpMDBOVE0wT1Rrd05qRWMKTUJvR0NTcUdTSWIzRFFFSkFSWU5hVzVtYjBCdmEzUmhMbU52YlRDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQwpnZ0VCQUxURTdJUkcrb1FaQkFTUTdEWTN5ZVRyd0FCZEkyQmdHMkZYS1NrVFBrOWVuTXd0eVV5RFhDT3RlT2cxOCsvL01BMlVUdmdTCkkrbjBmaUFoN0JpN2N4cGltbk9hai9rY2d2cGRuKzV3cEVmU0lES0FlRWc5VklRZjBmei9rczRYa3JOeFJoOGJhNloveXBPVlIyVEwKb3p1OHY2c2pHQ2lxSFNvaVBsNzhLSU5IeDlqTUIzUUdkVEhSeHNUendGUEdjVUV2TzdYdmp4eE1OOUZMWmRIa3d0QTZjWlhEYkhsQQp2K280RWJMSVJxWEZjM3ZGNXJzM0Z6K2NncVozSFZHbTkwVEZGY2JQYngvZUtjdnp5SGRZdDhQNXBpMzY0bWlqdDlOS3ROVjlGOVZkClB6K0dwL3J4bHcwaS9JV3hWMC92QnJXMTBIUGQ0Mmtyc09nSGlieEJZZzhDQXdFQUFUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUEKcnBZelpFb1ljUm8zWUY3Tnk0Z2RjOE9EU2xQUEtJZEx2d2hVVEdiUGR6SlUyaWZ4ekUvS2VUSEdtRnBqcGFrakRtbVdzcjJqOUZHVQovOVUwU2pxUG1KSFA1Z1liam16K3REM2plYUVrSUJEWnBjWWMrTXZlUWFBN3VETUlMQTJPVWhIdUZ1MFVKVmpHeGwyRUlweGl2QytJCkowUnBCUzVBRVJUNlY5MUZxdjJZbHdiNXNrbGhvWEdEeDlzK2wrVWQxTUxhZXdJdm5VSGRJUnRDMDJidmxoand0MHBuSUNEdEhNaWsKdk9pVFhqVEJKZ2w3WDlRNTFHbTYzNnE5cEpWalMxVDBnUjNjTnQ5SkpFL2ZvRGRPSzhKb3pSRnRGNGoxNHhlZ1hMdDdCVkJJWHVTTwpLNlAxYzA5bUNQUTFWSmJjajAxUzF6ZnJ2WitSWnZyeHIvMGFYUT09PC9kczpYNTA5Q2VydGlmaWNhdGU+PC9kczpYNTA5RGF0YT48L2RzOktleUluZm8+PC9kczpTaWduYXR1cmU+PHNhbWwycDpTdGF0dXMgeG1sbnM6c2FtbDJwPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6cHJvdG9jb2wiPjxzYW1sMnA6U3RhdHVzQ29kZSBWYWx1ZT0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnN0YXR1czpTdWNjZXNzIi8+PC9zYW1sMnA6U3RhdHVzPjxzYW1sMjpBc3NlcnRpb24gSUQ9ImlkMjc3ODQwNDc4ODc3ODQ3MjgyMTE5MzE4OTUiIElzc3VlSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBWZXJzaW9uPSIyLjAiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj48c2FtbDI6SXNzdWVyIEZvcm1hdD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOm5hbWVpZC1mb3JtYXQ6ZW50aXR5IiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+aHR0cDovL3d3dy5va3RhLmNvbS9leGthNWhhNmJrblk2T2tkODVkNzwvc2FtbDI6SXNzdWVyPjxkczpTaWduYXR1cmUgeG1sbnM6ZHM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPjxkczpTaWduZWRJbmZvPjxkczpDYW5vbmljYWxpemF0aW9uTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS8xMC94bWwtZXhjLWMxNG4jIi8+PGRzOlNpZ25hdHVyZU1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZHNpZy1tb3JlI3JzYS1zaGEyNTYiLz48ZHM6UmVmZXJlbmNlIFVSST0iI2lkMjc3ODQwNDc4ODc3ODQ3MjgyMTE5MzE4OTUiPjxkczpUcmFuc2Zvcm1zPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSIvPjxkczpUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiLz48L2RzOlRyYW5zZm9ybXM+PGRzOkRpZ2VzdE1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMDQveG1sZW5jI3NoYTI1NiIvPjxkczpEaWdlc3RWYWx1ZT42b3Ztd3BWNk00bHdBQ3BGZ0tqVm0rNlZ5U0t0dE9iVTF2Y2tvZlVWa2ZBPTwvZHM6RGlnZXN0VmFsdWU+PC9kczpSZWZlcmVuY2U+PC9kczpTaWduZWRJbmZvPjxkczpTaWduYXR1cmVWYWx1ZT5QdGhLcG1TY2k3OTdERExvTXR1TUJHNjgvbzZlcDFSSWxZR0RhRVR6Q1E1a0ZUdmQ3MWJ3RWpjOWl2UVdlU3VHM1U4aUM2THQvN0hmWEpUVDBLeWkvU2laa3pIZkl1bElKbTVQTm9memV1dXVFQVlyMFBoeUpidkJHUk44RWF0UEwwVjNsdlhPMU9YaHcxU2ltYlMwZEdoQkdCM1ovNEptajNBMGdGbmx5TkpOLzc4eFgrYlB1eEJLeFFYcFY5TTEwTnJLRUYrbzc1TVA3bm4xOW5KM002bG93SEFHZ3RhRFg5dTNGYTJ3Lzh4QXFGTnQ2NHdaMERQYWltQWl0RFBKdnRIL3VVN3k0cm1lUit0cXpqdnNHR3BtODNjNVNzd1dEZ1p4alBDSVdHRVRaVVdHQ0Rwb25WVzdUR0JuNDR4b1ZZUEhERStJcWJyWDdUVXIySFFoUGc9PTwvZHM6U2lnbmF0dXJlVmFsdWU+PGRzOktleUluZm8+PGRzOlg1MDlEYXRhPjxkczpYNTA5Q2VydGlmaWNhdGU+TUlJRHFEQ0NBcENnQXdJQkFnSUdBWWo4bEFZa01BMEdDU3FHU0liM0RRRUJDd1VBTUlHVU1Rc3dDUVlEVlFRR0V3SlZVekVUTUJFRwpBMVVFQ0F3S1EyRnNhV1p2Y201cFlURVdNQlFHQTFVRUJ3d05VMkZ1SUVaeVlXNWphWE5qYnpFTk1Bc0dBMVVFQ2d3RVQydDBZVEVVCk1CSUdBMVVFQ3d3TFUxTlBVSEp2ZG1sa1pYSXhGVEFUQmdOVkJBTU1ER1JsZGkwME5UTTBPVGt3TmpFY01Cb0dDU3FHU0liM0RRRUoKQVJZTmFXNW1iMEJ2YTNSaExtTnZiVEFlRncweU16QTJNamN4TVRFM05UbGFGdzB6TXpBMk1qY3hNVEU0TlRsYU1JR1VNUXN3Q1FZRApWUVFHRXdKVlV6RVRNQkVHQTFVRUNBd0tRMkZzYVdadmNtNXBZVEVXTUJRR0ExVUVCd3dOVTJGdUlFWnlZVzVqYVhOamJ6RU5NQXNHCkExVUVDZ3dFVDJ0MFlURVVNQklHQTFVRUN3d0xVMU5QVUhKdmRtbGtaWEl4RlRBVEJnTlZCQU1NREdSbGRpMDBOVE0wT1Rrd05qRWMKTUJvR0NTcUdTSWIzRFFFSkFSWU5hVzVtYjBCdmEzUmhMbU52YlRDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQwpnZ0VCQUxURTdJUkcrb1FaQkFTUTdEWTN5ZVRyd0FCZEkyQmdHMkZYS1NrVFBrOWVuTXd0eVV5RFhDT3RlT2cxOCsvL01BMlVUdmdTCkkrbjBmaUFoN0JpN2N4cGltbk9hai9rY2d2cGRuKzV3cEVmU0lES0FlRWc5VklRZjBmei9rczRYa3JOeFJoOGJhNloveXBPVlIyVEwKb3p1OHY2c2pHQ2lxSFNvaVBsNzhLSU5IeDlqTUIzUUdkVEhSeHNUendGUEdjVUV2TzdYdmp4eE1OOUZMWmRIa3d0QTZjWlhEYkhsQQp2K280RWJMSVJxWEZjM3ZGNXJzM0Z6K2NncVozSFZHbTkwVEZGY2JQYngvZUtjdnp5SGRZdDhQNXBpMzY0bWlqdDlOS3ROVjlGOVZkClB6K0dwL3J4bHcwaS9JV3hWMC92QnJXMTBIUGQ0Mmtyc09nSGlieEJZZzhDQXdFQUFUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUEKcnBZelpFb1ljUm8zWUY3Tnk0Z2RjOE9EU2xQUEtJZEx2d2hVVEdiUGR6SlUyaWZ4ekUvS2VUSEdtRnBqcGFrakRtbVdzcjJqOUZHVQovOVUwU2pxUG1KSFA1Z1liam16K3REM2plYUVrSUJEWnBjWWMrTXZlUWFBN3VETUlMQTJPVWhIdUZ1MFVKVmpHeGwyRUlweGl2QytJCkowUnBCUzVBRVJUNlY5MUZxdjJZbHdiNXNrbGhvWEdEeDlzK2wrVWQxTUxhZXdJdm5VSGRJUnRDMDJidmxoand0MHBuSUNEdEhNaWsKdk9pVFhqVEJKZ2w3WDlRNTFHbTYzNnE5cEpWalMxVDBnUjNjTnQ5SkpFL2ZvRGRPSzhKb3pSRnRGNGoxNHhlZ1hMdDdCVkJJWHVTTwpLNlAxYzA5bUNQUTFWSmJjajAxUzF6ZnJ2WitSWnZyeHIvMGFYUT09PC9kczpYNTA5Q2VydGlmaWNhdGU+PC9kczpYNTA5RGF0YT48L2RzOktleUluZm8+PC9kczpTaWduYXR1cmU+PHNhbWwyOlN1YmplY3QgeG1sbnM6c2FtbDI9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDphc3NlcnRpb24iPjxzYW1sMjpOYW1lSUQgRm9ybWF0PSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoxLjE6bmFtZWlkLWZvcm1hdDp1bnNwZWNpZmllZCI+ZGouamFpbjwvc2FtbDI6TmFtZUlEPjxzYW1sMjpTdWJqZWN0Q29uZmlybWF0aW9uIE1ldGhvZD0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmNtOmJlYXJlciI+PHNhbWwyOlN1YmplY3RDb25maXJtYXRpb25EYXRhIE5vdE9uT3JBZnRlcj0iMjAyMy0wNy0xMFQxMzo0NToyOS42NTlaIiBSZWNpcGllbnQ9Imh0dHBzOi8vbG9jYWwubWJ4LmNvbTo0MDAxL2F1dGgvYWhlYWQvc3NvIi8+PC9zYW1sMjpTdWJqZWN0Q29uZmlybWF0aW9uPjwvc2FtbDI6U3ViamVjdD48c2FtbDI6Q29uZGl0aW9ucyBOb3RCZWZvcmU9IjIwMjMtMDctMTBUMTM6MzU6MjkuNjU5WiIgTm90T25PckFmdGVyPSIyMDIzLTA3LTEwVDEzOjQ1OjI5LjY1OVoiIHhtbG5zOnNhbWwyPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6YXNzZXJ0aW9uIj48c2FtbDI6QXVkaWVuY2VSZXN0cmljdGlvbj48c2FtbDI6QXVkaWVuY2U+eHFPNTJDTkVMZDBoVkI5dmFYMWRfZGN3dVlBeEdVU3I8L3NhbWwyOkF1ZGllbmNlPjwvc2FtbDI6QXVkaWVuY2VSZXN0cmljdGlvbj48L3NhbWwyOkNvbmRpdGlvbnM+PHNhbWwyOkF1dGhuU3RhdGVtZW50IEF1dGhuSW5zdGFudD0iMjAyMy0wNy0xMFQxMzo0MDoyOS42NThaIiBTZXNzaW9uSW5kZXg9ImlkMTY4ODk5NjQyOTY1Ny4xMTQ1MDMyMDEyIiB4bWxuczpzYW1sMj0idXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFzc2VydGlvbiI+PHNhbWwyOkF1dGhuQ29udGV4dD48c2FtbDI6QXV0aG5Db250ZXh0Q2xhc3NSZWY+dXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOmFjOmNsYXNzZXM6UGFzc3dvcmRQcm90ZWN0ZWRUcmFuc3BvcnQ8L3NhbWwyOkF1dGhuQ29udGV4dENsYXNzUmVmPjwvc2FtbDI6QXV0aG5Db250ZXh0Pjwvc2FtbDI6QXV0aG5TdGF0ZW1lbnQ+PC9zYW1sMjpBc3NlcnRpb24+PC9zYW1sMnA6UmVzcG9uc2U+"
      iex> {:ok, saml_body} = saml_response |> Base.decode64()
      iex> {:ok, root} = SimpleXml.parse(saml_body)
      iex> SimpleXml.verify(root, public_key)
      {:error, :signature_verification_failed}
  """
  @spec verify(xml_node(), public_key()) :: :ok | {:error, any()}
  def verify(node, public_key) when is_tuple(node) do
    with {:ok, node_id} <- XmlNode.attribute(node, "ID"),
         {:ok, signature_node} <- XmlNode.first_child(node, ~r/.*:?Signature$/i),
         {:ok, signed_info_node} <- canonicalized_signed_info(signature_node),
         signed_info_xml <- XmlNode.to_string(signed_info_node),
         {:ok, reference_node} <- XmlNode.first_child(signed_info_node, ~r/.*:?Reference$/i),
         {:ok, reference_uri} <- XmlNode.attribute(reference_node, "URI"),
         :ok <- verify_signature_reference_uri(node_id, reference_uri),
         {:ok, digest_value_node} <- XmlNode.first_child(reference_node, ~r/.*:?DigestValue$/i),
         {:ok, digest_value} <- XmlNode.text(digest_value_node),
         node <- node |> remove_enveloped_signature() |> XmlNode.canonicalize(),
         computed_digest <- sha256_digest(node),
         :ok <- verify_digest(digest_value, computed_digest),
         {:ok, sig_value_node} <- XmlNode.first_child(signature_node, ~r/.*:?SignatureValue$/i),
         {:ok, signature_value} <- XmlNode.text(sig_value_node),
         {:ok, decoded_signature_value} <- Base.decode64(signature_value) do
      case :public_key.verify(signed_info_xml, :sha256, decoded_signature_value, public_key) do
        true -> :ok
        _ -> {:error, :signature_verification_failed}
      end
    else
      {:error, reason} ->
        {:error, reason}

      err ->
        Logger.error("Verification failed: #{inspect(err)}")
        {:error, :verification_failed}
    end
  end

  @spec remove_enveloped_signature(xml_node()) :: xml_node()
  defp remove_enveloped_signature(node) when is_tuple(node),
    do: node |> XmlNode.drop_children("*:Signature")

  @spec sha256_digest(xml_node()) :: String.t()
  defp sha256_digest(node) when is_tuple(node) do
    node
    |> XmlNode.to_string()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode64()
  end

  @spec verify_signature_reference_uri(String.t(), String.t()) :: :ok | {:error, any()}
  defp verify_signature_reference_uri(node_id, "#" <> node_id) when is_binary(node_id), do: :ok

  defp verify_signature_reference_uri(_node_id, _reference_uri),
    do: {:error, :invalid_signature_reference_uri}

  @spec verify_digest(String.t(), String.t()) :: :ok | {:error, any()}
  defp verify_digest(digest_value, digest_value) when is_binary(digest_value), do: :ok

  defp verify_digest(_digest_value, _computed_digest_value),
    do: {:error, :digest_verification_failed}

  @spec canonicalized_signed_info(xml_node()) :: {:ok, xml_node()} | {:error, any()}
  defp canonicalized_signed_info(signature_node) when is_tuple(signature_node) do
    with {:ok, namespace_attr} <- XmlNode.namespace_attribute(signature_node),
         {:ok, {tag, attrs, children}} <-
           XmlNode.first_child(signature_node, ~r/.*:?SignedInfo$/i),
         signed_info_node <- {tag, [namespace_attr | attrs], children} |> XmlNode.canonicalize() do
      {:ok, signed_info_node}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
