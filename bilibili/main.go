package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/tidwall/gjson"
)

var (
	wg       sync.WaitGroup
	g_result []string
	g_output string
)

func Init() {
	cmd_check_ffmpeg := exec.Command("which", "ffmpeg")
	output, _ := cmd_check_ffmpeg.Output()
	if len(output) == 0 {
		fmt.Println("你没有安装ffmpeg,请安装!!!")
		os.Exit(0)
	}
}

func GetPath() []string {
	var v_path string
	var result []string
	fmt.Print("请输入视频所在目录:")
	fmt.Scanln(&v_path)
	fmt.Print("请输出视频目录:")
	fmt.Scanln(&g_output)
	MKDir(g_output)

	res_path := BLDir(v_path)
	for i := 0; i < len(res_path); i++ {
		if strings.Contains(res_path[i], "entry.json") {
			result = append(result, strings.ReplaceAll(res_path[i], "/entry.json", ""))
		}
	}
	return result
}

func HBVideo(input string, output string) {
	b_n, err := ioutil.ReadFile(input + "/entry.json")
	if err != nil {
		fmt.Println("读取文件失败!-->" + input + "entry.json")
	}
	o_name := gjson.Get(string(b_n), "title").String()
	o_name = strings.ReplaceAll(output+"/"+o_name+".mp4", " ", "")

	// fmt.Println(o_name)
	// os.Exit(0)

	// run_ffmpeg := exec.Command("ffmpeg", "-i", input+"/64/video.m4s", "-i", input+"/64/audio.m4s", "-c:v copy -c:a aac -strict experimental", "a.mp4")
	cmd := exec.Command("ffmpeg", "-i", input+"/64/video.m4s", "-i", input+"/64/audio.m4s", "-c:v", "copy", "-c:a", "aac", o_name)
	// fmt.Println(run_ffmpeg.String())
	err = cmd.Run()
	if err != nil {
		fmt.Println("============")
		fmt.Println("合并视频失败!视频名为:" + o_name)
	} else {
		fmt.Println(o_name + "合成成功!!!")
	}
	defer wg.Done()
}

func BLDir(p string) []string {
	files, err := ioutil.ReadDir(p)
	// fmt.Println(p)
	if err != nil {
		fmt.Println("你的路径有误!请检查!")

		// os.Exit(0)
	}
	for _, file := range files {
		if file.IsDir() {
			BLDir(p + "/" + file.Name())
		} else {
			// fmt.Println(file.Name())
			g_result = append(g_result, p+"/"+file.Name())
			// fmt.Println(g_result)
		}
	}
	return g_result
}

func MKDir(p string) {
	os.MkdirAll(p, 0755)
}

func main() {
	Init()
	p := GetPath()
	for i := 0; i < len(p); i++ {
		wg.Add(1)
		go HBVideo(p[i], g_output)
	}
	wg.Wait()
}
