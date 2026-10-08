using System;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace KhuxSetup {
 public sealed class RangeUnavailable : Exception { public RangeUnavailable(string m):base(m){} }
 public class DownloadResponse : IDisposable {
  public Stream Stream; public int Code; public long Size; public string Range, Etag, Url;
  public Action Close;
  public void Dispose() { if(Stream!=null) Stream.Dispose(); if(Close!=null) Close(); }
 }
 public class Downloader {
  public volatile bool Done, Cancelled;
  public string Error, Status="Preparing download", EffectiveUrl;
  public long Total, Completed, NetworkBytes;
  public int Connections=1, Retries;
  public double BytesPerSecond;
  public int ChunkSize=16*1024*1024, MaxConnections=4;
  public readonly List<string> Events=new List<string>();
  readonly List<HttpWebRequest> active=new List<HttpWebRequest>();
  string[] urls; string path, sha256, parts; string etag;
  public static string Hash(string file) { using(var s=File.OpenRead(file)) using(var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(s)).Replace("-","").ToLowerInvariant(); }
  public void Note(string m) { lock(Events) Events.Add(DateTime.UtcNow.ToString("o")+" "+m); Status=m; }
  public void Cancel() { Cancelled=true; lock(active) foreach(var r in active) r.Abort(); }
  void Check() { if(Cancelled) throw new OperationCanceledException("Paused. Run setup again to resume."); }
  HttpWebRequest Request(string url) {
   Check(); var r=(HttpWebRequest)WebRequest.Create(url); r.Timeout=15000; r.ReadWriteTimeout=20000;
   r.UserAgent="KHUX-Preservation-Setup/2.0.0"; r.AutomaticDecompression=DecompressionMethods.None;
   r.ServicePoint.ConnectionLimit=MaxConnections; r.AllowAutoRedirect=true;
   lock(active) active.Add(r); return r;
  }
  void Release(HttpWebRequest r) { lock(active) active.Remove(r); }
  protected virtual DownloadResponse Open(string url,long start,long end,bool ranged) {
   var r=Request(url);
   try {
    if(ranged) { if(end>=0) r.AddRange(start,end); else r.AddRange(start); }
    if(ranged && !String.IsNullOrEmpty(etag)) r.Headers["If-Range"]=etag;
    var response=(HttpWebResponse)r.GetResponse();
    return new DownloadResponse { Stream=response.GetResponseStream(), Code=(int)response.StatusCode, Size=response.ContentLength,
     Range=response.Headers["Content-Range"], Etag=response.Headers["ETag"], Url=response.ResponseUri.AbsoluteUri,
     Close=delegate { response.Dispose(); Release(r); } };
   } catch { Release(r); throw; }
  }
  public void Start(string[] sources,string destination,long size,string digest) {
   urls=sources; path=destination; Total=size; sha256=String.IsNullOrEmpty(digest)?null:digest;
   if(Total<=0) throw new ArgumentException("Download size is missing or invalid.");
   Task.Factory.StartNew(delegate { try { Run(); } catch(Exception e) { Error=e.Message; Note(Error); } finally { Done=true; } });
  }
  void Backoff(int attempt, Exception e) {
   Check(); Interlocked.Increment(ref Retries); Note("Connection interrupted; retrying ("+(attempt+1)+"/5). "+e.Message);
   int seconds=Math.Min(16,1<<attempt);
   var w=e as WebException; var response=w==null?null:w.Response as HttpWebResponse;
   if(response!=null) { int retry; if(Int32.TryParse(response.Headers["Retry-After"],out retry)) seconds=Math.Min(60,Math.Max(seconds,retry)); response.Dispose(); }
   for(int i=0;i<seconds*10;i++) { Check(); Thread.Sleep(100); }
  }
  string Chunk(int i) { return Path.Combine(parts,i.ToString("D6")+".part"); }
  long Length(int i) { return Math.Min(ChunkSize,Total-(long)i*ChunkSize); }
  bool ValidChunk(int i) {
   string p=Chunk(i); if(!File.Exists(p)) return false;
   long len=new FileInfo(p).Length;
   if(len>Length(i)) { Quarantine(p); return false; }
   if(len!=Length(i)) return false;
   if(!File.Exists(p+".sha256") || File.ReadAllText(p+".sha256")!=Hash(p)) { Quarantine(p); return false; }
   return true;
  }
  static void Quarantine(string p) { if(File.Exists(p)) File.Move(p,p+".corrupt-"+Guid.NewGuid().ToString("N")); }
  void Seed() {
   string old=path+".partial";
   if(!File.Exists(old)) return;
   long n=new FileInfo(old).Length; if(n==0 || n>Total) return;
   Note("Reusing existing partial download without changing the original.");
   using(var input=File.OpenRead(old)) {
    int i=0; byte[] buffer=new byte[1024*1024];
    while(input.Position<n) {
     Check(); long count=Math.Min(Length(i),n-input.Position); string p=Chunk(i);
     if(File.Exists(p)) { input.Position+=count; i++; continue; }
     using(var output=File.Create(p)) { long left=count; while(left>0) { int got=input.Read(buffer,0,(int)Math.Min(buffer.Length,left)); if(got==0) throw new IOException("Partial file changed during setup."); output.Write(buffer,0,got); left-=got; } }
     if(count==Length(i)) File.WriteAllText(p+".sha256",Hash(p)); i++;
    }
   }
  }
  void GetChunk(int i) {
   string p=Chunk(i); long wanted=Length(i);
   for(int attempt=0;attempt<5;attempt++) {
    Check(); long have=File.Exists(p)?new FileInfo(p).Length:0;
    if(have==wanted) { File.WriteAllText(p+".sha256",Hash(p)); return; }
    try {
     long start=(long)i*ChunkSize+have, end=(long)i*ChunkSize+wanted-1;
     using(var response=Open(urls[attempt%urls.Length],start,end,true)) {
      EffectiveUrl=response.Url;
      string expected="bytes "+start+"-"+end+"/"+Total;
      if(response.Code!=206 || response.Range!=expected || response.Size!=wanted-have)
       throw new RangeUnavailable("Server cannot safely resume ranges; switching to one connection.");
      if(i==0 && have==0) etag=response.Etag;
      if(attempt>0) Note("Connection recovered. Continuing saved download.");
      using(var input=response.Stream) using(var output=new FileStream(p,FileMode.Append,FileAccess.Write,FileShare.Read)) {
       byte[] buffer=new byte[256*1024]; long left=wanted-have;
       while(left>0) { Check(); int got=input.Read(buffer,0,(int)Math.Min(left,buffer.Length)); if(got==0) throw new IOException("Server closed the connection early."); output.Write(buffer,0,got); Interlocked.Add(ref NetworkBytes,got); Interlocked.Add(ref Completed,got); left-=got; }
       output.Flush(true);
      }
     }
     File.WriteAllText(p+".sha256",Hash(p)); return;
    } catch(RangeUnavailable) { throw; }
      catch(Exception e) { if(attempt==4) throw new IOException("Download paused after five attempts. Run setup again to resume. "+e.Message,e); Backoff(attempt,e); }
   }
  }
  void Serial() {
   Connections=1; string p=path+".serial.partial";
   for(int attempt=0;attempt<5;attempt++) {
    Check();
    try {
     long have=File.Exists(p)?new FileInfo(p).Length:0;
     if(have==Total) return;
     if(have>Total) { Quarantine(p); have=0; }
     using(var response=Open(urls[attempt%urls.Length],have,-1,have>0)) {
      if(have>0 && response.Code==200) { Quarantine(p); have=0; }
      else if(have>0 && (response.Code!=206 || response.Range!="bytes "+have+"-"+(Total-1)+"/"+Total)) throw new IOException("Invalid resume response.");
      if(response.Size!=Total-have) throw new IOException("Unexpected download size.");
      Completed=have;
      using(var input=response.Stream) using(var output=new FileStream(p,FileMode.Append,FileAccess.Write,FileShare.Read)) {
       byte[] buffer=new byte[256*1024]; long left=Total-have;
       while(left>0) { Check(); int got=input.Read(buffer,0,(int)Math.Min(left,buffer.Length)); if(got==0) throw new IOException("Server closed the connection early."); output.Write(buffer,0,got); Interlocked.Add(ref NetworkBytes,got); Interlocked.Add(ref Completed,got); left-=got; } output.Flush(true);
      }
     } return;
    } catch(Exception e) { if(attempt==4) throw; Backoff(attempt,e); }
   }
  }
  void Run() {
   Directory.CreateDirectory(Path.GetDirectoryName(path));
   if(File.Exists(path)) { if(sha256!=null && Hash(path)==sha256) { Completed=Total; Note("Verified cached file; no download needed."); return; } Quarantine(path); }
   // The URL or trusted hash determines a cache namespace: chunks cannot cross versions.
   string key=sha256;
   if(key==null) using(var h=SHA256.Create()) key=BitConverter.ToString(h.ComputeHash(System.Text.Encoding.UTF8.GetBytes(urls[0]))).Replace("-","");
   parts=path+".chunks-"+key.Substring(0,16); Directory.CreateDirectory(parts);
   var watch=Stopwatch.StartNew();
   for(int recovery=0;recovery<2;recovery++) {
    Seed(); Completed=0; var pending=new List<int>(); int count=(int)((Total+ChunkSize-1)/ChunkSize);
    for(int i=0;i<count;i++) { if(ValidChunk(i)) Completed+=Length(i); else { pending.Add(i); if(File.Exists(Chunk(i))) Completed+=new FileInfo(Chunk(i)).Length; } }
    bool serial=false; int cursor=0, n=1; double previous=0; bool probing=true;
    while(cursor<pending.Count) {
     Check(); int take=Math.Min(n,pending.Count-cursor); Connections=take; Note("Downloading with "+take+" connection"+(take==1?"":"s")+"; partial files are saved.");
     long before=NetworkBytes; var timer=Stopwatch.StartNew(); var tasks=new List<Task>();
     for(int j=0;j<take;j++) { int index=pending[cursor+j]; tasks.Add(Task.Factory.StartNew(delegate { GetChunk(index); })); }
     try { Task.WaitAll(tasks.ToArray()); }
     catch(AggregateException e) { if(e.Flatten().InnerExceptions[0] is RangeUnavailable) { Note(e.Flatten().InnerExceptions[0].Message); serial=true; break; } throw e.Flatten().InnerExceptions[0]; }
     double rate=(NetworkBytes-before)/Math.Max(.001,timer.Elapsed.TotalSeconds); BytesPerSecond=rate;
     if(Retries>0) { n=Math.Max(1,n/2); probing=false; }
     else if(probing && previous>0 && rate<previous*1.15) { n=Math.Max(1,n/2); probing=false; Note("Additional connections did not help; using "+n+"."); }
     else if(probing && n<MaxConnections) n=Math.Min(MaxConnections,n*2);
     previous=rate; cursor+=take;
    }
    string assembled=serial?path+".serial.partial":path+".assembled.partial";
    if(serial) Serial(); else {
     Note("Combining verified chunks.");
     using(var output=File.Create(assembled)) for(int i=0;i<count;i++) { Check(); using(var input=File.OpenRead(Chunk(i))) input.CopyTo(output); }
    }
    Check(); Note("Verifying complete download.");
    if(new FileInfo(assembled).Length==Total && (sha256==null || Hash(assembled)==sha256)) {
     File.Move(assembled,path); Completed=Total; Note("Download verified. Resume chunks retained for recovery."); return;
    }
    Quarantine(assembled); string damaged=parts+".corrupt-"+Guid.NewGuid().ToString("N"); Directory.Move(parts,damaged); Directory.CreateDirectory(parts);
    // Do not reseed a suspect old prefix after an integrity failure.
    if(File.Exists(path+".partial")) Quarantine(path+".partial");
    Note("Integrity check failed. Suspect bytes preserved separately; retrying a clean download.");
   }
   throw new IOException("Download failed its integrity check twice. No game files were installed. Try again later.");
  }
 }
}
