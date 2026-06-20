program UHFPrimeReader;

{$R 'UAC.res' 'UAC.rc'}

uses
  Vcl.Forms,
  untMain in 'untMain.pas' {fmMain},
  untThreadWork in 'untThreadWork.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmMain, fmMain);
  Application.Run;
end.
