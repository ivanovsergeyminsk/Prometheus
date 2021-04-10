unit Prometheus.DelphiStats;

interface
uses
  Prometheus.Metrics,

  System.Generics.Collections,
  System.Analytics.AppAnalytics
  ;

type
  /// <summary>
  /// Collects basic Delphi metrics about the current process. This is not meant to be an especially serious collector,
  /// more of a producer of sample data so users of the library see something when they install it.
  /// </summary>
  TDelphiStats = class sealed
  private const
    L_MEASURE = 'measure';
    L_DESC    = 'description';
    MEASURE   = 'KB';
    DESC_PeakWorkingSetSize         = '������� ������ �������� ������';
    DESC_WorkingSetSize             = '������� ������ �������� ������';
    DESC_QuotaPeakPagedPoolUsage    = '������� ������������� ������������ ����';
    DESC_QuotaPagedPoolUsage        = '������� ������������� ������������ ����';
    DESC_QuotaPeakNonPagedPoolUsage = '������� ������������� �������������� ����';
    DESC_QuotaNonPagedPoolUsage     = '������� ������������� �������������� ����';
    DESC_PagefileUsage              = '����� ����� ������, ���������� ����������� ������';
    DESC_PeakPagefileUsage          = '������� ����� ������, ���������� ����������� ������';

  private
    FPeakWorkingSetSize: IGauge;
    FWorkingSetSize: IGauge;
    FQuotaPeakPagedPoolUsage: IGauge;
    FQuotaPagedPoolUsage: IGauge;
    FQuotaPeakNonPagedPoolUsage: IGauge;
    FQuotaNonPagedPoolUsage: IGauge;
    FPagefileUsage: IGauge;
    FPeakPagefileUsage: IGauge;

    FRequestCount: ICounter;

    FUpdateLock: TObject;

    Metrics: IMetricFactory;
    procedure UpdateMetrics;
  public
    TestCounter: ICounter;
    TestGauge: IGauge;
    TestSummary: ISummary;
    TestHitogram: IHistogram;

    constructor Create(Registry: ICollectorRegistry);
    destructor Destroy; override;
  end;

implementation
uses
  System.SysUtils,
  System.SyncObjs,
  PsAPI, Windows
  ;

{ TDelphiStats }

constructor TDelphiStats.Create(Registry: ICollectorRegistry);
begin
  FUpdateLock := TObject.Create;
  Metrics := TMetrics.WithCustomRegistry(Registry);

  FPeakWorkingSetSize := Metrics.CreateGauge('process_memory_PeakWorkingSetSize',
                                             '������� ������ �������� ������',
                                             [L_DESC, L_MEASURE]);
  FWorkingSetSize := Metrics.CreateGauge('process_memory_WorkingSetSize',
                                         '������� ������ �������� ������',
                                         [L_DESC, L_MEASURE]);

  FQuotaPeakPagedPoolUsage := Metrics.CreateGauge('process_memory_QuotaPeakPagedPoolUsage',
                                                  '������� ������������� ������������ ����',
                                                  [L_DESC, L_MEASURE]);

  FQuotaPagedPoolUsage := Metrics.CreateGauge('process_memory_QuotaPagedPoolUsage',
                                              '������� ������������� ������������ ����',
                                              [L_DESC, L_MEASURE]);

  FQuotaPeakNonPagedPoolUsage := Metrics.CreateGauge('process_memory_QuotaPeakNonPagedPoolUsage',
                                                     '������� ������������� �������������� ����',
                                                     [L_DESC, L_MEASURE]);

  FQuotaNonPagedPoolUsage := Metrics.CreateGauge('process_memory_QuotaNonPagedPoolUsage',
                                                 '������� ������������� �������������� ����',
                                                 [L_DESC, L_MEASURE]);

  FPagefileUsage := Metrics.CreateGauge('process_memory_PagefileUsage',
                                        '����� ����� ������, ���������� ����������� ������',
                                        [L_DESC, L_MEASURE]);

  FPeakPagefileUsage := Metrics.CreateGauge('process_memory_PeakPagefileUsage',
                                            '������� ����� ������, ���������� ����������� ������',
                                            [L_DESC, L_MEASURE]);


  FRequestCount := Metrics.CreateCounter('delphi_metric_req', '���������� �������� �������');

  TestCounter  := Metrics.CreateCounter('delhi_test_counter', '���� counter');
  TestGauge    := Metrics.CreateGauge('delhi_test_gauge', '���� gauge');
  TestSummary  := Metrics.CreateSummary('delhi_test_summary', '���� summary');
  TestHitogram := Metrics.CreateHistogram('delhi_test_histogram', '���� histogram');
  Registry.AddBeforeCollectorCallback(UpdateMetrics);
end;

destructor TDelphiStats.Destroy;
begin
  FPeakWorkingSetSize         := nil;
  FWorkingSetSize             := nil;
  FQuotaPeakPagedPoolUsage    := nil;
  FQuotaPagedPoolUsage        := nil;
  FQuotaPeakNonPagedPoolUsage := nil;
  FPagefileUsage              := nil;
  FPeakPagefileUsage          := nil;
  TestCounter := nil;
  TestGauge   := nil;
  Metrics                     := nil;
  FUpdateLock.Free;
  inherited;
end;

procedure TDelphiStats.UpdateMetrics;
begin
  TMonitor.Enter(FUpdateLock);
  try
    var PMC: PPROCESS_MEMORY_COUNTERS;
    var cb: integer := SizeOf(_PROCESS_MEMORY_COUNTERS);
    GetMem(PMC, cb);
    PMC^.cb := cb;
    if GetProcessMemoryInfo(GetCurrentProcess, PMC, cb) then begin
      FPeakWorkingSetSize.Labels([DESC_PeakWorkingSetSize,MEASURE]).&Set(pmc^.PeakWorkingSetSize / 1024);
      FWorkingSetSize.Labels([DESC_WorkingSetSize,MEASURE]).&Set(pmc^.WorkingSetSize / 1024);
      FQuotaPeakPagedPoolUsage.Labels([DESC_QuotaPeakPagedPoolUsage,MEASURE]).&Set(pmc^.QuotaPeakPagedPoolUsage / 1024);
      FQuotaPagedPoolUsage.Labels([DESC_QuotaPagedPoolUsage,MEASURE]).&Set(pmc^.QuotaPagedPoolUsage / 1024);
      FQuotaPeakNonPagedPoolUsage.Labels([DESC_QuotaPeakNonPagedPoolUsage,MEASURE]).&Set(pmc^.QuotaPeakNonPagedPoolUsage / 1024);
      FQuotaNonPagedPoolUsage.Labels([DESC_QuotaNonPagedPoolUsage,MEASURE]).&Set(pmc^.QuotaNonPagedPoolUsage / 1024);
      FPagefileUsage.Labels([DESC_PagefileUsage,MEASURE]).&Set(pmc^.PagefileUsage / 1024);
      FPeakPagefileUsage.Labels([DESC_PeakPagefileUsage,MEASURE]).&Set(pmc^.PeakPagefileUsage / 1024);
    end;
    FreeMem(PMC);

    FRequestCount.Inc;
  finally
    TMonitor.Exit(FUpdateLock);
  end;
end;

end.
