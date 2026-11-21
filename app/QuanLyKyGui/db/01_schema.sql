USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   1. KHACH_HANG
   ============================================================ */
CREATE TABLE dbo.KHACH_HANG
(
    MaKH            INT IDENTITY(1,1) NOT NULL,
    HoTen           NVARCHAR(100)     NOT NULL,
    SoDienThoai     VARCHAR(20)       NOT NULL,
    Email           VARCHAR(254)      NULL,
    DiaChi          NVARCHAR(255)     NULL,
    NgayTao         DATETIME2(0)      NOT NULL CONSTRAINT DF_KHACH_HANG_NgayTao DEFAULT SYSDATETIME(),
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaKH),
    CONSTRAINT UQ_KHACH_HANG_SoDienThoai UNIQUE (SoDienThoai),
    CONSTRAINT CK_KHACH_HANG_HoTen CHECK (LEN(LTRIM(RTRIM(HoTen))) > 0),
    CONSTRAINT CK_KHACH_HANG_SoDienThoai CHECK
    (
        LEN(SoDienThoai) BETWEEN 8 AND 20
        AND
        (
            SoDienThoai NOT LIKE '%[^0-9]%'
            OR
            (
                SoDienThoai LIKE '+%'
                AND SUBSTRING(SoDienThoai, 2, 20) NOT LIKE '%[^0-9]%'
            )
        )
    ),
    CONSTRAINT CK_KHACH_HANG_Email CHECK (Email IS NULL OR Email = '' OR Email LIKE '%_@_%._%')
);
GO

/* ============================================================
   2. NHAN_VIEN
   ============================================================ */
CREATE TABLE dbo.NHAN_VIEN
(
    MaNV            INT IDENTITY(1,1) NOT NULL,
    HoTen           NVARCHAR(100)     NOT NULL,
    SoDienThoai     VARCHAR(20)       NULL,
    Email           VARCHAR(254)      NULL,
    ChucVu          NVARCHAR(20)      NOT NULL,
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_NHAN_VIEN_TrangThai DEFAULT N'Đang làm việc',
    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaNV),
    CONSTRAINT CK_NHAN_VIEN_HoTen CHECK (LEN(LTRIM(RTRIM(HoTen))) > 0),
    CONSTRAINT CK_NHAN_VIEN_ChucVu CHECK (ChucVu IN (N'Nhân viên', N'Thu ngân', N'Quản lý')),
    CONSTRAINT CK_NHAN_VIEN_TrangThai CHECK (TrangThai IN (N'Đang làm việc', N'Đã nghỉ')),
    CONSTRAINT CK_NHAN_VIEN_Email CHECK (Email IS NULL OR Email = '' OR Email LIKE '%_@_%._%'),
    CONSTRAINT CK_NHAN_VIEN_SoDienThoai CHECK
    (
        SoDienThoai IS NULL
        OR
        (
            LEN(SoDienThoai) BETWEEN 8 AND 20
            AND
            (
                SoDienThoai NOT LIKE '%[^0-9]%'
                OR
                (
                    SoDienThoai LIKE '+%'
                    AND SUBSTRING(SoDienThoai, 2, 20) NOT LIKE '%[^0-9]%'
                )
            )
        )
    )
);
GO

/* ============================================================
   3. THUONG_HIEU
   ============================================================ */
CREATE TABLE dbo.THUONG_HIEU
(
    MaTH            INT IDENTITY(1,1) NOT NULL,
    TenThuongHieu   NVARCHAR(100)     NOT NULL,
    MoTa            NVARCHAR(500)     NULL,
    CONSTRAINT PK_THUONG_HIEU PRIMARY KEY (MaTH),
    CONSTRAINT UQ_THUONG_HIEU_Ten UNIQUE (TenThuongHieu),
    CONSTRAINT CK_THUONG_HIEU_Ten CHECK (LEN(LTRIM(RTRIM(TenThuongHieu))) > 0)
);
GO

/* ============================================================
   4. DANH_MUC
   ============================================================ */
CREATE TABLE dbo.DANH_MUC
(
    MaDM            INT IDENTITY(1,1) NOT NULL,
    TenDanhMuc      NVARCHAR(100)     NOT NULL,
    MoTa            NVARCHAR(500)     NULL,
    CONSTRAINT PK_DANH_MUC PRIMARY KEY (MaDM),
    CONSTRAINT UQ_DANH_MUC_Ten UNIQUE (TenDanhMuc),
    CONSTRAINT CK_DANH_MUC_Ten CHECK (LEN(LTRIM(RTRIM(TenDanhMuc))) > 0)
);
GO

/* ============================================================
   5. PHIEU_KY_GUI
   ============================================================ */
CREATE TABLE dbo.PHIEU_KY_GUI
(
    MaPKG           INT IDENTITY(1,1) NOT NULL,
    MaKH            INT               NOT NULL,
    MaNV            INT               NOT NULL,
    NgayKyGui       DATETIME2(0)      NOT NULL CONSTRAINT DF_PHIEU_KY_GUI_NgayKyGui DEFAULT SYSDATETIME(),
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_PHIEU_KY_GUI_TrangThai DEFAULT N'Đang xử lý',
    GhiChu          NVARCHAR(500)     NULL,
    CONSTRAINT PK_PHIEU_KY_GUI PRIMARY KEY (MaPKG),
    CONSTRAINT FK_PHIEU_KY_GUI_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT FK_PHIEU_KY_GUI_NHAN_VIEN FOREIGN KEY (MaNV) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_PHIEU_KY_GUI_TrangThai CHECK (TrangThai IN (N'Đang xử lý', N'Đang ký gửi', N'Đã hoàn tất', N'Đã hủy'))
);
GO

/* ============================================================
   6. SAN_PHAM
   ============================================================ */
CREATE TABLE dbo.SAN_PHAM
(
    MaSP                INT IDENTITY(1,1) NOT NULL,
    MaPKG               INT               NOT NULL,
    MaDM                INT               NOT NULL,
    MaTH                INT               NULL,
    TenSP               NVARCHAR(200)     NOT NULL,
    MoTa                NVARCHAR(1000)    NULL,
    KichThuoc           NVARCHAR(50)      NULL,
    MauSac              NVARCHAR(50)      NULL,
    ChatLieu            NVARCHAR(50)      NULL,
    TinhTrang           NVARCHAR(100)     NOT NULL,
    GiaDeXuat           DECIMAL(12,0)     NULL,
    GiaDangBan          DECIMAL(12,0)     NULL,
    TrangThaiTiepNhan   NVARCHAR(20)      NOT NULL CONSTRAINT DF_SAN_PHAM_TrangThaiTiepNhan DEFAULT N'Chờ xử lý',
    TrangThaiBan        NVARCHAR(20)      NULL,
    NgayDangBan         DATETIME2(0)      NULL,
    CONSTRAINT PK_SAN_PHAM PRIMARY KEY (MaSP),
    CONSTRAINT FK_SAN_PHAM_PHIEU_KY_GUI FOREIGN KEY (MaPKG) REFERENCES dbo.PHIEU_KY_GUI(MaPKG),
    CONSTRAINT FK_SAN_PHAM_DANH_MUC FOREIGN KEY (MaDM) REFERENCES dbo.DANH_MUC(MaDM),
    CONSTRAINT FK_SAN_PHAM_THUONG_HIEU FOREIGN KEY (MaTH) REFERENCES dbo.THUONG_HIEU(MaTH),
    CONSTRAINT CK_SAN_PHAM_Ten CHECK (LEN(LTRIM(RTRIM(TenSP))) > 0),
    CONSTRAINT CK_SAN_PHAM_TinhTrang CHECK (LEN(LTRIM(RTRIM(TinhTrang))) > 0),
    CONSTRAINT CK_SAN_PHAM_GiaDeXuat CHECK (GiaDeXuat IS NULL OR GiaDeXuat BETWEEN 0 AND 500000000),
    CONSTRAINT CK_SAN_PHAM_GiaDangBan CHECK (GiaDangBan IS NULL OR GiaDangBan BETWEEN 0 AND 500000000),
    CONSTRAINT CK_SAN_PHAM_ChuaDuyetKhongGia CHECK (TrangThaiTiepNhan = N'Đã chấp nhận' OR GiaDangBan IS NULL),
    CONSTRAINT CK_SAN_PHAM_TrangThaiTiepNhan CHECK (TrangThaiTiepNhan IN (N'Chờ xử lý', N'Đã chấp nhận', N'Từ chối')),
    CONSTRAINT CK_SAN_PHAM_TrangThaiBan CHECK (TrangThaiBan IS NULL OR TrangThaiBan IN (N'Chưa đăng bán', N'Đang bán', N'Đang giữ', N'Đã bán', N'Đã trả lại')),
    CONSTRAINT CK_SAN_PHAM_TrangThaiPhuHop CHECK
    (
        (TrangThaiTiepNhan IN (N'Chờ xử lý', N'Từ chối') AND TrangThaiBan IS NULL)
        OR
        (TrangThaiTiepNhan = N'Đã chấp nhận' AND TrangThaiBan IS NOT NULL)
    ),
    CONSTRAINT CK_SAN_PHAM_DangBanCanGia CHECK (TrangThaiBan <> N'Đang bán' OR GiaDangBan IS NOT NULL),
    CONSTRAINT CK_SAN_PHAM_DangBanCanNgay CHECK (TrangThaiBan <> N'Đang bán' OR NgayDangBan IS NOT NULL),
    CONSTRAINT CK_SAN_PHAM_ChuaDangBanNgay CHECK (TrangThaiBan <> N'Chưa đăng bán' OR NgayDangBan IS NULL),
    CONSTRAINT CK_SAN_PHAM_NgayDangBanKhiNull CHECK (TrangThaiBan IS NOT NULL OR NgayDangBan IS NULL)
);
GO

/* ============================================================
   7. DON_HANG
   ============================================================ */
CREATE TABLE dbo.DON_HANG
(
    MaDH            INT IDENTITY(1,1) NOT NULL,
    MaKH            INT               NOT NULL,
    MaNV            INT               NOT NULL,
    NgayLap         DATETIME2(0)      NOT NULL CONSTRAINT DF_DON_HANG_NgayLap DEFAULT SYSDATETIME(),
    HanThanhToan    DATETIME2(0)      NOT NULL,
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_DON_HANG_TrangThai DEFAULT N'Chờ thanh toán',
    LyDoHuy         NVARCHAR(500)     NULL,
    GhiChu          NVARCHAR(500)     NULL,
    CONSTRAINT PK_DON_HANG PRIMARY KEY (MaDH),
    CONSTRAINT FK_DON_HANG_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT FK_DON_HANG_NHAN_VIEN FOREIGN KEY (MaNV) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_DON_HANG_TrangThai CHECK (TrangThai IN (N'Chờ thanh toán', N'Đang xử lý', N'Hoàn tất', N'Đã hủy')),
    CONSTRAINT CK_DON_HANG_HanThanhToan CHECK (HanThanhToan >= NgayLap),
    CONSTRAINT CK_DON_HANG_LyDoHuy CHECK
    (
        (TrangThai = N'Đã hủy' AND LyDoHuy IS NOT NULL AND LEN(LTRIM(RTRIM(LyDoHuy))) > 0)
        OR
        (TrangThai <> N'Đã hủy' AND LyDoHuy IS NULL)
    )
);
GO

/* ============================================================
   8. CHI_TIET_DON_HANG
   ============================================================ */
CREATE TABLE dbo.CHI_TIET_DON_HANG
(
    MaCTDH              INT IDENTITY(1,1) NOT NULL,
    MaDH                INT               NOT NULL,
    MaSP                INT               NOT NULL,
    GiaNiemYetLucBan    DECIMAL(12,0)     NOT NULL,
    GiamGia             DECIMAL(12,0)     NOT NULL CONSTRAINT DF_CHI_TIET_DON_HANG_GiamGia DEFAULT 0,
    GiaBanThucTe        AS (CAST(GiaNiemYetLucBan - GiamGia AS DECIMAL(12,0))) PERSISTED,
    CONSTRAINT PK_CHI_TIET_DON_HANG PRIMARY KEY (MaCTDH),
    CONSTRAINT FK_CHI_TIET_DON_HANG_DON_HANG FOREIGN KEY (MaDH) REFERENCES dbo.DON_HANG(MaDH),
    CONSTRAINT FK_CHI_TIET_DON_HANG_SAN_PHAM FOREIGN KEY (MaSP) REFERENCES dbo.SAN_PHAM(MaSP),
    CONSTRAINT UQ_CHI_TIET_DON_HANG_DH_SP UNIQUE (MaDH, MaSP),
    CONSTRAINT CK_CHI_TIET_DON_HANG_Gia CHECK (GiaNiemYetLucBan BETWEEN 0 AND 500000000),
    CONSTRAINT CK_CHI_TIET_DON_HANG_GiamGia CHECK (GiamGia >= 0 AND GiamGia * 2 <= GiaNiemYetLucBan)
);
GO

/* ============================================================
   9. THANH_TOAN_DON_HANG
   ============================================================ */
CREATE TABLE dbo.THANH_TOAN_DON_HANG
(
    MaTTDH          INT IDENTITY(1,1) NOT NULL,
    MaDH            INT               NOT NULL,
    SoTien          DECIMAL(12,0)     NOT NULL,
    NgayTao         DATETIME2(0)      NOT NULL CONSTRAINT DF_THANH_TOAN_DON_HANG_NgayTao DEFAULT SYSDATETIME(),
    NgayHoanTat     DATETIME2(0)      NULL,
    PhuongThuc      NVARCHAR(20)      NOT NULL,
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_THANH_TOAN_DON_HANG_TrangThai DEFAULT N'Chờ xử lý',
    MaGiaoDich      VARCHAR(100)      NULL,
    GhiChu          NVARCHAR(500)     NULL,
    CONSTRAINT PK_THANH_TOAN_DON_HANG PRIMARY KEY (MaTTDH),
    CONSTRAINT FK_THANH_TOAN_DON_HANG_DON_HANG FOREIGN KEY (MaDH) REFERENCES dbo.DON_HANG(MaDH),
    CONSTRAINT CK_THANH_TOAN_DON_HANG_SoTien CHECK (SoTien > 0),
    CONSTRAINT CK_THANH_TOAN_DON_HANG_PhuongThuc CHECK (PhuongThuc IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ', N'Ví điện tử')),
    CONSTRAINT CK_THANH_TOAN_DON_HANG_TrangThai CHECK (TrangThai IN (N'Chờ xử lý', N'Thành công', N'Thất bại')),
    CONSTRAINT CK_THANH_TOAN_DON_HANG_NgayHoanTat CHECK
    (
        (TrangThai = N'Thành công' AND NgayHoanTat IS NOT NULL)
        OR
        (TrangThai <> N'Thành công' AND NgayHoanTat IS NULL)
    ),
    CONSTRAINT CK_THANH_TOAN_DON_HANG_Ngay CHECK (NgayHoanTat IS NULL OR NgayHoanTat >= NgayTao)
);
GO

/* ============================================================
   10. PHIEU_THANH_TOAN_KY_GUI
   ============================================================ */
CREATE TABLE dbo.PHIEU_THANH_TOAN_KY_GUI
(
    MaPTTKG         INT IDENTITY(1,1) NOT NULL,
    MaKH            INT               NOT NULL,
    MaNV            INT               NOT NULL,
    NgayLap         DATETIME2(0)      NOT NULL CONSTRAINT DF_PHIEU_THANH_TOAN_KY_GUI_NgayLap DEFAULT SYSDATETIME(),
    NgayThanhToan   DATETIME2(0)      NULL,
    PhuongThuc      NVARCHAR(20)      NOT NULL,
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_PHIEU_THANH_TOAN_KY_GUI_TrangThai DEFAULT N'Chờ thanh toán',
    MaGiaoDich      VARCHAR(100)      NULL,
    GhiChu          NVARCHAR(500)     NULL,
    CONSTRAINT PK_PHIEU_THANH_TOAN_KY_GUI PRIMARY KEY (MaPTTKG),
    CONSTRAINT FK_PHIEU_THANH_TOAN_KY_GUI_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT FK_PHIEU_THANH_TOAN_KY_GUI_NHAN_VIEN FOREIGN KEY (MaNV) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_PHIEU_THANH_TOAN_KY_GUI_PhuongThuc CHECK (PhuongThuc IN (N'Tiền mặt', N'Chuyển khoản')),
    CONSTRAINT CK_PHIEU_THANH_TOAN_KY_GUI_TrangThai CHECK (TrangThai IN (N'Chờ thanh toán', N'Đã thanh toán')),
    CONSTRAINT CK_PHIEU_THANH_TOAN_KY_GUI_Ngay CHECK
    (
        (TrangThai = N'Đã thanh toán' AND NgayThanhToan IS NOT NULL)
        OR
        (TrangThai = N'Chờ thanh toán' AND NgayThanhToan IS NULL)
    ),
    CONSTRAINT CK_PHIEU_THANH_TOAN_KY_GUI_Ngay2 CHECK (NgayThanhToan IS NULL OR NgayThanhToan >= NgayLap)
);
GO

/* ============================================================
   11. CHI_TIET_THANH_TOAN_KY_GUI
   ============================================================ */
CREATE TABLE dbo.CHI_TIET_THANH_TOAN_KY_GUI
(
    MaCTTTKG            INT IDENTITY(1,1) NOT NULL,
    MaPTTKG             INT               NOT NULL,
    MaCTDH              INT               NOT NULL,
    GiaBanTinhToan      DECIMAL(12,0)     NOT NULL,
    TienHoaHong         AS (CAST(ROUND(GiaBanTinhToan * 0.20, 0) AS DECIMAL(12,0))) PERSISTED,
    TienThucNhan        AS (CAST(GiaBanTinhToan - ROUND(GiaBanTinhToan * 0.20, 0) AS DECIMAL(12,0))) PERSISTED,
    CONSTRAINT PK_CHI_TIET_THANH_TOAN_KY_GUI PRIMARY KEY (MaCTTTKG),
    CONSTRAINT FK_CHI_TIET_THANH_TOAN_KY_GUI_PHIEU FOREIGN KEY (MaPTTKG) REFERENCES dbo.PHIEU_THANH_TOAN_KY_GUI(MaPTTKG),
    CONSTRAINT FK_CHI_TIET_THANH_TOAN_KY_GUI_CTDH FOREIGN KEY (MaCTDH) REFERENCES dbo.CHI_TIET_DON_HANG(MaCTDH),
    CONSTRAINT UQ_CHI_TIET_THANH_TOAN_KY_GUI_CTDH UNIQUE (MaCTDH),
    CONSTRAINT CK_CHI_TIET_THANH_TOAN_KY_GUI_Gia CHECK (GiaBanTinhToan >= 0)
);
GO

/* ============================================================
   Indexes
   ============================================================ */
CREATE INDEX IX_PHIEU_KY_GUI_MaKH        ON dbo.PHIEU_KY_GUI(MaKH);
CREATE INDEX IX_PHIEU_KY_GUI_MaNV        ON dbo.PHIEU_KY_GUI(MaNV);
CREATE INDEX IX_PHIEU_KY_GUI_TrangThai   ON dbo.PHIEU_KY_GUI(TrangThai, NgayKyGui);

CREATE INDEX IX_SAN_PHAM_MaPKG           ON dbo.SAN_PHAM(MaPKG);
CREATE INDEX IX_SAN_PHAM_MaDM            ON dbo.SAN_PHAM(MaDM);
CREATE INDEX IX_SAN_PHAM_MaTH            ON dbo.SAN_PHAM(MaTH);
CREATE INDEX IX_SAN_PHAM_TenSP           ON dbo.SAN_PHAM(TenSP);
CREATE INDEX IX_SAN_PHAM_TrangThaiBan    ON dbo.SAN_PHAM(TrangThaiBan, MaDM);
CREATE INDEX IX_SAN_PHAM_TrangThaiTiepNhan ON dbo.SAN_PHAM(TrangThaiTiepNhan);

CREATE INDEX IX_DON_HANG_MaKH            ON dbo.DON_HANG(MaKH);
CREATE INDEX IX_DON_HANG_MaNV            ON dbo.DON_HANG(MaNV);
CREATE INDEX IX_DON_HANG_TrangThai       ON dbo.DON_HANG(TrangThai, NgayLap);
CREATE INDEX IX_DON_HANG_HanThanhToan    ON dbo.DON_HANG(HanThanhToan);

CREATE INDEX IX_CTDH_MaDH                ON dbo.CHI_TIET_DON_HANG(MaDH);
CREATE INDEX IX_CTDH_MaSP                ON dbo.CHI_TIET_DON_HANG(MaSP);

CREATE INDEX IX_THANH_TOAN_MaDH          ON dbo.THANH_TOAN_DON_HANG(MaDH);
CREATE INDEX IX_THANH_TOAN_TrangThai     ON dbo.THANH_TOAN_DON_HANG(TrangThai, NgayTao);

CREATE INDEX IX_PTTKG_MaKH               ON dbo.PHIEU_THANH_TOAN_KY_GUI(MaKH);
CREATE INDEX IX_PTTKG_MaNV               ON dbo.PHIEU_THANH_TOAN_KY_GUI(MaNV);
CREATE INDEX IX_PTTKG_TrangThai          ON dbo.PHIEU_THANH_TOAN_KY_GUI(TrangThai, NgayLap);

CREATE INDEX IX_CTTTKG_MaPTTKG           ON dbo.CHI_TIET_THANH_TOAN_KY_GUI(MaPTTKG);
GO

PRINT N'Schema created: 11 tables + indexes.';
GO
