USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   14_hardening.sql
   Vá lỗ hổng toàn vẹn dữ liệu phát hiện khi review.
   Chạy lại nhiều lần an toàn: không xoá bảng, không mất dữ liệu.
   ============================================================ */

PRINT N'--- 14_hardening: bắt đầu ---';
GO

/* ------------------------------------------------------------
   0. Chuẩn hoá dữ liệu cũ trước khi siết ràng buộc
   ------------------------------------------------------------ */
BEGIN TRANSACTION;

/* 0.1 Số điện thoại: bỏ dấu cách, chấm, gạch nối (giữ số và dấu + đầu) */
UPDATE dbo.KHACH_HANG
SET SoDienThoai = REPLACE(REPLACE(REPLACE(SoDienThoai, ' ', ''), '.', ''), '-', '')
WHERE SoDienThoai LIKE '%[ .-]%';

UPDATE dbo.NHAN_VIEN
SET SoDienThoai = REPLACE(REPLACE(REPLACE(SoDienThoai, ' ', ''), '.', ''), '-', '')
WHERE SoDienThoai IS NOT NULL AND SoDienThoai LIKE '%[ .-]%';

/* 0.2 NgayDangBan rơi sau NgayLap của đơn đã dùng sản phẩm:
       dời mốc đăng bán về NgayLap SỚM NHẤT của các đơn chứa sản phẩm đó.
       Dùng MIN vì bất biến #14 yêu cầu NgayLap >= NgayDangBan cho MỌI đơn,
       nên NgayDangBan phải nhỏ hơn hoặc bằng đơn sớm nhất. */
UPDATE sp
SET NgayDangBan = x.NgayLapSomNhat
FROM dbo.SAN_PHAM sp
JOIN
(
    SELECT c.MaSP, MIN(d.NgayLap) AS NgayLapSomNhat
    FROM dbo.CHI_TIET_DON_HANG c
    JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
    WHERE d.TrangThai <> N'Đã hủy'
    GROUP BY c.MaSP
) x ON x.MaSP = sp.MaSP
WHERE sp.NgayDangBan IS NOT NULL
  AND x.NgayLapSomNhat < sp.NgayDangBan;

COMMIT TRANSACTION;
GO

/* ------------------------------------------------------------
   0.5 Siết SĐT về dạng chuẩn: chỉ số, tối đa một dấu + ở đầu.
       Không siết ở CSDL thì INSERT trực tiếp vẫn chèn được
       "0901 000 001" và tạo trùng hồ sơ với "0901000001".
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE SoDienThoai LIKE '%[ .-]%' OR SoDienThoai LIKE '%+%[0-9]%')
    THROW 53002, N'Còn số điện thoại khách hàng chưa chuẩn hoá. Chạy lại phần 0.1 trước.', 1;
GO

IF EXISTS (SELECT 1 FROM dbo.NHAN_VIEN
           WHERE SoDienThoai IS NOT NULL
             AND (SoDienThoai LIKE '%[ .-]%' OR SoDienThoai LIKE '%+%[0-9]%'))
    THROW 53003, N'Còn số điện thoại nhân viên chưa chuẩn hoá. Chạy lại phần 0.1 trước.', 1;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_KHACH_HANG_SoDienThoai'
             AND parent_object_id = OBJECT_ID(N'dbo.KHACH_HANG'))
    ALTER TABLE dbo.KHACH_HANG DROP CONSTRAINT CK_KHACH_HANG_SoDienThoai;
GO

ALTER TABLE dbo.KHACH_HANG WITH CHECK ADD CONSTRAINT CK_KHACH_HANG_SoDienThoai
CHECK
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
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_NHAN_VIEN_SoDienThoai'
                 AND parent_object_id = OBJECT_ID(N'dbo.NHAN_VIEN'))
BEGIN
    ALTER TABLE dbo.NHAN_VIEN WITH CHECK ADD CONSTRAINT CK_NHAN_VIEN_SoDienThoai
    CHECK
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
    );
END
GO

/* ------------------------------------------------------------
   0.6 Trần giá nghiệp vụ 500.000.000 đ (khớp Theme.PriceMax)
       Áp cho giá đề xuất, giá đăng bán và giá niêm yết trong đơn.
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE GiaDeXuat > 500000000 OR GiaDangBan > 500000000)
    THROW 53004, N'Có sản phẩm có giá trên 500.000.000 đ. Sửa dữ liệu trước khi nâng cấp.', 1;
GO

IF EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG WHERE GiaNiemYetLucBan > 500000000)
    THROW 53005, N'Có chi tiết đơn hàng có giá niêm yết trên 500.000.000 đ. Sửa dữ liệu trước khi nâng cấp.', 1;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_SAN_PHAM_GiaDeXuat' AND parent_object_id = OBJECT_ID(N'dbo.SAN_PHAM'))
    ALTER TABLE dbo.SAN_PHAM DROP CONSTRAINT CK_SAN_PHAM_GiaDeXuat;
GO
ALTER TABLE dbo.SAN_PHAM WITH CHECK ADD CONSTRAINT CK_SAN_PHAM_GiaDeXuat
CHECK (GiaDeXuat IS NULL OR GiaDeXuat BETWEEN 0 AND 500000000);
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_SAN_PHAM_GiaDangBan' AND parent_object_id = OBJECT_ID(N'dbo.SAN_PHAM'))
    ALTER TABLE dbo.SAN_PHAM DROP CONSTRAINT CK_SAN_PHAM_GiaDangBan;
GO
ALTER TABLE dbo.SAN_PHAM WITH CHECK ADD CONSTRAINT CK_SAN_PHAM_GiaDangBan
CHECK (GiaDangBan IS NULL OR GiaDangBan BETWEEN 0 AND 500000000);
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_CHI_TIET_DON_HANG_Gia' AND parent_object_id = OBJECT_ID(N'dbo.CHI_TIET_DON_HANG'))
    ALTER TABLE dbo.CHI_TIET_DON_HANG DROP CONSTRAINT CK_CHI_TIET_DON_HANG_Gia;
GO
ALTER TABLE dbo.CHI_TIET_DON_HANG WITH CHECK ADD CONSTRAINT CK_CHI_TIET_DON_HANG_Gia
CHECK (GiaNiemYetLucBan BETWEEN 0 AND 500000000);
GO

/* Phải kiểm tra dữ liệu cũ TRƯỚC khi bỏ ràng buộc cũ */
IF EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG WHERE GiamGia * 2 > GiaNiemYetLucBan)
    THROW 53001, N'Còn dòng chi tiết đơn hàng giảm giá trên 50%. Sửa dữ liệu trước khi nâng cấp.', 1;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_CHI_TIET_DON_HANG_GiamGia'
             AND parent_object_id = OBJECT_ID(N'dbo.CHI_TIET_DON_HANG'))
    ALTER TABLE dbo.CHI_TIET_DON_HANG DROP CONSTRAINT CK_CHI_TIET_DON_HANG_GiamGia;
GO

ALTER TABLE dbo.CHI_TIET_DON_HANG WITH CHECK ADD CONSTRAINT CK_CHI_TIET_DON_HANG_GiamGia
CHECK (GiamGia >= 0 AND GiamGia * 2 <= GiaNiemYetLucBan);
GO

/* ------------------------------------------------------------
   2. TR_CTDH: khoá chi tiết đơn hàng sau khi đã thu tiền
   ------------------------------------------------------------ */
CREATE OR ALTER TRIGGER dbo.TR_CTDH
ON dbo.CHI_TIET_DON_HANG
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    /* Dòng thực sự mới thêm (không nằm trong deleted) */
    IF EXISTS (SELECT 1 FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.MaCTDH = i.MaCTDH))
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            LEFT JOIN deleted d ON d.MaCTDH = i.MaCTDH
            JOIN dbo.SAN_PHAM sp ON sp.MaSP = i.MaSP
            JOIN dbo.DON_HANG dh ON dh.MaDH = i.MaDH
            WHERE d.MaCTDH IS NULL
              AND
              (
                  dh.TrangThai <> N'Chờ thanh toán'
                  OR EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t
                             WHERE t.MaDH = i.MaDH AND t.TrangThai = N'Thành công')
                  OR sp.TrangThaiBan IS NULL
                  OR sp.TrangThaiBan <> N'Đang bán'
                  OR sp.GiaDangBan IS NULL
                  OR i.GiaNiemYetLucBan <> sp.GiaDangBan
                  OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.CHI_TIET_DON_HANG c2
                      JOIN dbo.DON_HANG d2 ON d2.MaDH = c2.MaDH
                      WHERE c2.MaSP = i.MaSP
                        AND c2.MaCTDH <> i.MaCTDH
                        AND d2.TrangThai <> N'Đã hủy'
                  )
              )
        )
            THROW 50002, N'Không thể thêm sản phẩm: đơn phải Chờ thanh toán và chưa thu tiền, sản phẩm phải Đang bán, đúng giá niêm yết và chưa thuộc đơn khác.', 1;

        UPDATE sp
        SET TrangThaiBan = N'Đang giữ'
        FROM dbo.SAN_PHAM sp
        JOIN inserted i ON i.MaSP = sp.MaSP
        WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.MaCTDH = i.MaCTDH);
    END

    /* Dòng bị sửa: chặn sau khi đơn đã có tiền hoặc đã rời Chờ thanh toán */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaCTDH = i.MaCTDH
        WHERE i.MaDH <> d.MaDH
           OR i.MaSP <> d.MaSP
           OR i.GiaNiemYetLucBan <> d.GiaNiemYetLucBan
           OR i.GiamGia <> d.GiamGia
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN deleted d ON d.MaCTDH = i.MaCTDH
            WHERE (i.MaDH <> d.MaDH OR i.MaSP <> d.MaSP
                   OR i.GiaNiemYetLucBan <> d.GiaNiemYetLucBan
                   OR i.GiamGia <> d.GiamGia)
              AND
              (
                  EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t
                          WHERE t.MaDH = d.MaDH AND t.TrangThai = N'Thành công')
                  OR EXISTS (SELECT 1 FROM dbo.DON_HANG dh
                             WHERE dh.MaDH = d.MaDH AND dh.TrangThai <> N'Chờ thanh toán')
              )
        )
            THROW 50019, N'Không thể sửa chi tiết đơn hàng đã thu tiền hoặc đã rời trạng thái Chờ thanh toán.', 1;
    END

    /* Dòng thực sự bị xoá (không còn trong inserted) */
    IF EXISTS (SELECT 1 FROM deleted d WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.MaCTDH = d.MaCTDH))
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM deleted d
            LEFT JOIN inserted i ON i.MaCTDH = d.MaCTDH
            JOIN dbo.DON_HANG dh ON dh.MaDH = d.MaDH
            WHERE i.MaCTDH IS NULL
              AND
              (
                  dh.TrangThai <> N'Chờ thanh toán'
                  OR EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t
                             WHERE t.MaDH = d.MaDH AND t.TrangThai = N'Thành công')
              )
        )
            THROW 50003, N'Chỉ được xoá sản phẩm khỏi đơn đang Chờ thanh toán và chưa thu tiền.', 1;

        UPDATE sp
        SET TrangThaiBan = N'Đang bán'
        FROM dbo.SAN_PHAM sp
        JOIN deleted d ON d.MaSP = sp.MaSP
        JOIN dbo.DON_HANG dh ON dh.MaDH = d.MaDH
        WHERE dh.TrangThai = N'Chờ thanh toán'
          AND sp.TrangThaiBan = N'Đang giữ'
          AND NOT EXISTS (SELECT 1 FROM inserted i WHERE i.MaCTDH = d.MaCTDH);
    END
END
GO

/* ------------------------------------------------------------
   3. TR_SAN_PHAM: trả hàng là chấm dứt, không bán lại;
      Đã bán phải thuộc đơn còn hiệu lực
   ------------------------------------------------------------ */
CREATE OR ALTER TRIGGER dbo.TR_SAN_PHAM
ON dbo.SAN_PHAM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* 3.1 Trả hàng: chỉ từ Chưa đăng bán / Đang bán và không thuộc đơn còn hiệu lực */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaSP = i.MaSP
        WHERE i.TrangThaiBan = N'Đã trả lại'
          AND (d.TrangThaiBan IS NULL OR d.TrangThaiBan <> N'Đã trả lại')
          AND
          (
              (d.TrangThaiBan IS NULL OR d.TrangThaiBan NOT IN (N'Chưa đăng bán', N'Đang bán'))
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.CHI_TIET_DON_HANG c
                  JOIN dbo.DON_HANG dh ON dh.MaDH = c.MaDH
                  WHERE c.MaSP = i.MaSP AND dh.TrangThai <> N'Đã hủy'
              )
          )
    )
        THROW 50001, N'Không thể trả lại: sản phẩm đang giữ/đã bán hoặc đang thuộc đơn hàng chưa hủy.', 1;

    /* 3.2 Đã trả lại là trạng thái cuối */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaSP = i.MaSP
        WHERE d.TrangThaiBan = N'Đã trả lại'
          AND (i.TrangThaiBan IS NULL OR i.TrangThaiBan <> N'Đã trả lại')
    )
        THROW 50020, N'Sản phẩm đã trả lại người ký gửi thì không thể đưa trở lại sàn.', 1;

    /* 3.3 Đã bán chỉ khi sản phẩm nằm trong một đơn còn hiệu lực */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaSP = i.MaSP
        WHERE i.TrangThaiBan = N'Đã bán'
          AND (d.TrangThaiBan IS NULL OR d.TrangThaiBan <> N'Đã bán')
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.CHI_TIET_DON_HANG c
              JOIN dbo.DON_HANG dh ON dh.MaDH = c.MaDH
              WHERE c.MaSP = i.MaSP AND dh.TrangThai <> N'Đã hủy'
          )
    )
        THROW 50021, N'Chỉ được chuyển sản phẩm sang Đã bán thông qua một đơn hàng còn hiệu lực.', 1;

    UPDATE p
    SET TrangThai = dbo.fn_TrangThaiPhieuKyGui(p.MaPKG)
    FROM dbo.PHIEU_KY_GUI p
    WHERE p.MaPKG IN (SELECT MaPKG FROM inserted UNION SELECT MaPKG FROM deleted)
      AND p.TrangThai <> dbo.fn_TrangThaiPhieuKyGui(p.MaPKG);
END
GO

/* ------------------------------------------------------------
   4. TR_CTTTKG: không để phiếu quyết toán trở thành rỗng
   ------------------------------------------------------------ */
CREATE OR ALTER TRIGGER dbo.TR_CTTTKG
ON dbo.CHI_TIET_THANH_TOAN_KY_GUI
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted d
        JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = d.MaPTTKG
        WHERE p.TrangThai = N'Đã thanh toán'
    )
        THROW 50011, N'Không được sửa/xoá chi tiết của phiếu quyết toán đã thanh toán.', 1;

    /* 4.1 Không xoá chi tiết cuối cùng của phiếu đang chờ chi */
    IF EXISTS
    (
        SELECT 1
        FROM deleted d
        JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = d.MaPTTKG
        WHERE p.TrangThai = N'Chờ thanh toán'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI c
              WHERE c.MaPTTKG = d.MaPTTKG
                AND NOT EXISTS (SELECT 1 FROM deleted x WHERE x.MaCTTTKG = c.MaCTTTKG)
          )
    )
        THROW 50022, N'Không thể xoá chi tiết cuối cùng của phiếu quyết toán. Hãy huỷ phiếu thay vì để phiếu rỗng.', 1;

    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = i.MaPTTKG
            WHERE p.TrangThai <> N'Chờ thanh toán'
        )
            THROW 50012, N'Chỉ được thêm chi tiết vào phiếu quyết toán đang chờ thanh toán.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
            WHERE d.TrangThai <> N'Hoàn tất'
        )
            THROW 50013, N'Chỉ quyết toán sản phẩm thuộc đơn hàng đã Hoàn tất.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
            JOIN dbo.PHIEU_KY_GUI pkg ON pkg.MaPKG = sp.MaPKG
            JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = i.MaPTTKG
            WHERE pkg.MaKH <> p.MaKH
        )
            THROW 50014, N'Tất cả sản phẩm trong phiếu quyết toán phải thuộc cùng một người ký gửi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            WHERE i.GiaBanTinhToan <> c.GiaBanThucTe
        )
            THROW 50015, N'Giá bán tính toán phải bằng giá bán thực tế của chi tiết đơn hàng.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_THANH_TOAN_KY_GUI x ON x.MaCTDH = i.MaCTDH AND x.MaCTTTKG <> i.MaCTTTKG
        )
            THROW 50016, N'Chi tiết đơn hàng này đã được quyết toán.', 1;
    END
END
GO

/* ------------------------------------------------------------
   5. sp_TaoDonHang: giảm giá tối đa 50%, ngày lập không trước ngày đăng bán
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.sp_TaoDonHang
    @MaKH         INT,
    @MaNV         INT,
    @NgayLap      DATETIME2(0) = NULL,
    @HanThanhToan DATETIME2(0) = NULL,
    @GhiChu       NVARCHAR(500) = NULL,
    @ChiTiet      dbo.ChiTietDonHangType READONLY,
    @MaDH         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NgayLap = ISNULL(@NgayLap, SYSDATETIME());
    SET @HanThanhToan = ISNULL(@HanThanhToan, DATEADD(DAY, 3, @NgayLap));

    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 51301, N'Khách hàng không tồn tại.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc')
        THROW 51302, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;

    IF NOT EXISTS (SELECT 1 FROM @ChiTiet)
        THROW 51303, N'Đơn hàng phải có ít nhất một sản phẩm.', 1;

    IF @HanThanhToan < @NgayLap
        THROW 51304, N'Hạn thanh toán phải sau ngày lập đơn.', 1;

    IF EXISTS (SELECT 1 FROM @ChiTiet GROUP BY MaSP HAVING COUNT(*) > 1)
        THROW 51305, N'Một sản phẩm không được xuất hiện hai lần trong cùng đơn hàng.', 1;

    IF EXISTS (SELECT 1 FROM @ChiTiet WHERE GiamGia < 0)
        THROW 51306, N'Giảm giá không được âm.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        LEFT JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE sp.MaSP IS NULL
    )
        THROW 51307, N'Sản phẩm không tồn tại.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE sp.TrangThaiBan IS NULL OR sp.TrangThaiBan <> N'Đang bán'
    )
        THROW 51308, N'Chỉ được thêm sản phẩm đang bán vào đơn hàng.', 1;

    /* Giảm giá tối đa 50% giá niêm yết */
    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE ct.GiamGia * 2 > sp.GiaDangBan
    )
        THROW 51311, N'Giảm giá không được vượt quá 50% giá niêm yết.', 1;

    /* Không lập đơn cho sản phẩm chưa tới ngày đăng bán */
    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE sp.NgayDangBan IS NOT NULL AND @NgayLap < sp.NgayDangBan
    )
        THROW 51312, N'Ngày lập đơn không được trước ngày sản phẩm được đăng bán.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaSP = ct.MaSP
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE d.TrangThai <> N'Đã hủy'
    )
        THROW 51310, N'Sản phẩm đã thuộc một đơn hàng khác chưa hủy.', 1;

    BEGIN TRANSACTION;

    INSERT dbo.DON_HANG (MaKH, MaNV, NgayLap, HanThanhToan, TrangThai, LyDoHuy, GhiChu)
    VALUES (@MaKH, @MaNV, @NgayLap, @HanThanhToan, N'Chờ thanh toán', NULL, @GhiChu);

    SET @MaDH = CAST(SCOPE_IDENTITY() AS INT);

    INSERT dbo.CHI_TIET_DON_HANG (MaDH, MaSP, GiaNiemYetLucBan, GiamGia)
    SELECT @MaDH, ct.MaSP, sp.GiaDangBan, ct.GiamGia
    FROM @ChiTiet ct
    JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP;

    COMMIT TRANSACTION;
END
GO

/* ------------------------------------------------------------
   6. sp_GhiNhanThanhToan: ngày thu không trước ngày lập đơn
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.sp_GhiNhanThanhToan
    @MaDH        INT,
    @SoTien      DECIMAL(12,0),
    @PhuongThuc  NVARCHAR(20),
    @TrangThai   NVARCHAR(20) = N'Thành công',
    @MaGiaoDich  VARCHAR(100) = NULL,
    @GhiChu      NVARCHAR(500) = NULL,
    @NgayTao     DATETIME2(0) = NULL,
    @MaTTDH      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NgayTao = ISNULL(@NgayTao, SYSDATETIME());

    DECLARE @TrangThaiDon NVARCHAR(20);
    DECLARE @NgayLap DATETIME2(0);
    DECLARE @TongTien DECIMAL(12,0);
    DECLARE @DaThu DECIMAL(12,0);

    SELECT @TrangThaiDon = TrangThai, @NgayLap = NgayLap
    FROM dbo.DON_HANG WHERE MaDH = @MaDH;

    IF @TrangThaiDon IS NULL
        THROW 51401, N'Đơn hàng không tồn tại.', 1;

    IF @TrangThaiDon <> N'Chờ thanh toán'
        THROW 51402, N'Chỉ ghi nhận thanh toán cho đơn đang chờ thanh toán.', 1;

    IF @SoTien IS NULL OR @SoTien <= 0
        THROW 51403, N'Số tiền thanh toán phải lớn hơn 0.', 1;

    IF @NgayTao < @NgayLap
        THROW 51407, N'Ngày thu tiền không được trước ngày lập đơn.', 1;

    IF @PhuongThuc NOT IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ', N'Ví điện tử')
        THROW 51404, N'Phương thức thanh toán không hợp lệ.', 1;

    IF @TrangThai NOT IN (N'Chờ xử lý', N'Thành công', N'Thất bại')
        THROW 51405, N'Trạng thái giao dịch không hợp lệ.', 1;

    IF @TrangThai = N'Thành công'
    BEGIN
        SELECT @TongTien = ISNULL(SUM(GiaBanThucTe), 0)
        FROM dbo.CHI_TIET_DON_HANG
        WHERE MaDH = @MaDH;

        SELECT @DaThu = ISNULL(SUM(SoTien), 0)
        FROM dbo.THANH_TOAN_DON_HANG
        WHERE MaDH = @MaDH AND TrangThai = N'Thành công';

        IF @DaThu >= @TongTien
            THROW 51406, N'Đơn hàng đã được thanh toán đủ.', 1;
    END

    INSERT dbo.THANH_TOAN_DON_HANG
        (MaDH, SoTien, NgayTao, NgayHoanTat, PhuongThuc, TrangThai, MaGiaoDich, GhiChu)
    VALUES
        (@MaDH, @SoTien, @NgayTao,
         CASE WHEN @TrangThai = N'Thành công' THEN @NgayTao ELSE NULL END,
         @PhuongThuc, @TrangThai, @MaGiaoDich, @GhiChu);

    SET @MaTTDH = CAST(SCOPE_IDENTITY() AS INT);
END
GO

/* ------------------------------------------------------------
   7. sp_CapNhatThanhToan: xử lý giao dịch đang treo
   ------------------------------------------------------------ */
DROP PROCEDURE IF EXISTS dbo.sp_CapNhatThanhToan;
GO
CREATE PROCEDURE dbo.sp_CapNhatThanhToan
    @MaTTDH     INT,
    @TrangThai  NVARCHAR(20),
    @GhiChu     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @HienTai NVARCHAR(20);
    DECLARE @MaDH INT;
    DECLARE @SoTien DECIMAL(12,0);

    SELECT @HienTai = TrangThai, @MaDH = MaDH, @SoTien = SoTien
    FROM dbo.THANH_TOAN_DON_HANG WHERE MaTTDH = @MaTTDH;

    IF @HienTai IS NULL
        THROW 52201, N'Giao dịch thanh toán không tồn tại.', 1;

    IF @TrangThai NOT IN (N'Thành công', N'Thất bại')
        THROW 52202, N'Chỉ được chuyển giao dịch sang Thành công hoặc Thất bại.', 1;

    IF @HienTai <> N'Chờ xử lý'
        THROW 52203, N'Chỉ cập nhật được giao dịch đang Chờ xử lý.', 1;

    IF @TrangThai = N'Thành công'
    BEGIN
        DECLARE @TongTien DECIMAL(12,0), @DaThu DECIMAL(12,0);
        SELECT @TongTien = ISNULL(SUM(GiaBanThucTe), 0) FROM dbo.CHI_TIET_DON_HANG WHERE MaDH = @MaDH;
        SELECT @DaThu = ISNULL(SUM(SoTien), 0) FROM dbo.THANH_TOAN_DON_HANG
        WHERE MaDH = @MaDH AND TrangThai = N'Thành công' AND MaTTDH <> @MaTTDH;

        IF @DaThu + @SoTien > @TongTien
            THROW 52204, N'Xác nhận giao dịch này sẽ vượt quá giá trị đơn hàng. Kiểm tra lại số tiền.', 1;

        UPDATE dbo.THANH_TOAN_DON_HANG
        SET TrangThai = N'Thành công',
            NgayHoanTat = SYSDATETIME(),
            GhiChu = ISNULL(@GhiChu, GhiChu)
        WHERE MaTTDH = @MaTTDH;
    END
    ELSE
    BEGIN
        UPDATE dbo.THANH_TOAN_DON_HANG
        SET TrangThai = N'Thất bại',
            NgayHoanTat = NULL,
            GhiChu = ISNULL(@GhiChu, GhiChu)
        WHERE MaTTDH = @MaTTDH;
    END
END
GO

/* ------------------------------------------------------------
   8. sp_HuyDonHang: tự đóng giao dịch treo rồi mới huỷ đơn
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.sp_HuyDonHang
    @MaDH  INT,
    @LyDo  NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TrangThai NVARCHAR(20);

    SELECT @TrangThai = TrangThai FROM dbo.DON_HANG WHERE MaDH = @MaDH;

    IF @TrangThai IS NULL
        THROW 51501, N'Đơn hàng không tồn tại.', 1;

    IF @TrangThai <> N'Chờ thanh toán'
        THROW 51502, N'Chỉ được huỷ đơn đang chờ thanh toán.', 1;

    IF @LyDo IS NULL OR LEN(LTRIM(RTRIM(@LyDo))) = 0
        THROW 51503, N'Phải nhập lý do huỷ đơn.', 1;

    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = @MaDH AND TrangThai = N'Thành công')
        THROW 51504, N'Không thể huỷ đơn đã có thanh toán thành công.', 1;

    BEGIN TRANSACTION;

    /* Giao dịch đang chờ của đơn bị huỷ được đánh dấu Thất bại */
    UPDATE dbo.THANH_TOAN_DON_HANG
    SET TrangThai = N'Thất bại',
        NgayHoanTat = NULL,
        GhiChu = ISNULL(GhiChu + N' | ', N'') + N'Đơn hàng đã huỷ'
    WHERE MaDH = @MaDH AND TrangThai = N'Chờ xử lý';

    UPDATE dbo.DON_HANG
    SET TrangThai = N'Đã hủy',
        LyDoHuy = @LyDo
    WHERE MaDH = @MaDH;

    COMMIT TRANSACTION;
END
GO

PRINT N'--- 14_hardening: hoàn tất ---';
GO
