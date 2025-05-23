package clock

type Alarm struct {
	Time      int64  `json:"time"`
	Msg       string `json:"msg"`
	CreatedAt int64  `json:"createdAt"`
}
