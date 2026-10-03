function paths = writeReport(spec, folder)
%WRITEREPORT Write independent reports; require a new destination folder.
spec=fm.core.validateSpec(spec);
if isstring(folder) && isscalar(folder), folder=char(folder); end
if ~ischar(folder) || ~isrow(folder) || isempty(strtrim(folder)), error('fm:ReportFolder','Provide a nonempty output folder path.'); end
plain=fm.export.toText(spec); latex=fm.export.toLatex(spec);
if exist(folder,'file') || exist(folder,'dir'), error('fm:ReportExists','Destination already exists: %s. Choose a new folder.',folder); end
[ok,message,messageId]=mkdir(folder);
if ~ok || ~isempty(messageId), error('fm:ReportFolder','Cannot create new output folder %s: %s',folder,message); end
paths=struct('text',fullfile(folder,'equations.txt'),'latex',fullfile(folder,'equations.tex'),'markdown',fullfile(folder,'report.md'));
report=['# Formula report: ' spec.name newline newline 'Independent formula export (schema version 1).' newline newline '```text' newline plain '```' newline newline 'Original derivative equations:' newline newline '```text' newline strjoin(spec.equations,newline) newline '```' newline newline 'Original output expressions:' newline newline '```text' newline];
for k=1:numel(spec.outputNames)
    n=spec.outputNames{k}; report=[report n ' = ' spec.outputs.(n) newline]; %#ok<AGROW>
end
report=[report '```' newline];
writeOne(paths.text,plain); writeOne(paths.latex,latex); writeOne(paths.markdown,report);
end
function writeOne(path,content)
[fid,message]=fopen(path,'w','n','UTF-8');
if fid<0, error('fm:ReportWrite','Cannot open %s: %s',path,message); end
cleanup=onCleanup(@() fclose(fid));
count=fprintf(fid,'%s',content);
[message,number]=ferror(fid);
if count<0 || number~=0, error('fm:ReportWrite','Failed writing %s: %s',path,message); end
end
